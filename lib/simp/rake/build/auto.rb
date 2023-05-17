#!/usr/bin/rake -T

require 'simp/rake'
require 'json'
require 'simp/rake/build/constants'
require 'simp/rake/helpers'
require 'simp/packer/iso_vars_json'

include Simp::Rake

class SIMPBuildException < StandardError
end

require 'simp/build/release_mapper'
module Simp; end
module Simp::Rake; end
module Simp::Rake::Build
  class Auto < ::Rake::TaskLib

    # Commands that are required by some part of the rake stack
    #
    # Use an array for commands that may have multiple valid options
    BUILD_REQUIRED_COMMANDS = [
      'basename',
      'cat',
      'checkmodule',
      'chmod',
      'cp',
      'cpio',
      'createrepo',
      'date',
      'diff',
      'dirname',
      'file',
      'find',
      'gawk',
      'git',
      'gpg',
      'grep',
      'gzip',
      'implantisomd5',
      'install',
      'isoinfo',
      'm4',
      'make',
      'mkdir',
      'mktemp',
      ['python','python2','python3'],
      'readlink',
      'repoclosure',
      'rm',
      'rpm',
      'rpmbuild',
      'rpmdb',
      'rpmsign',
      'sed',
      'semodule_package',
      'setfacl',
      'sh',
      'sort',
      'tail',
      'tar',
      'uname',
      'uniq',
      'wc',
      'which',
      'xargs',
      ['dnf','yum'],
      'yumdownloader'
    ]

    include Simp::Rake::Build::Constants

    def initialize( run_dir )
      init_member_vars(run_dir)

      define
    end

    # define rake tasks
    def define
      namespace :build do

        desc <<-EOM
        Automatically detect and build a SIMP ISO for a target SIMP release.

        This task runs all other build tasks

        Arguments:
          * :iso_paths    => Path to source ISO(s) and/or directories  [Default: '.']
                             NOTE: colon-delimited list
                             If not set, will build all enabled distributions
          * :release      => SIMP release to build (e.g., '6.X')
                             The Full list can be found in '#{File.join(@build_dir, 'release_mappings.yaml')}'
                             Default: #{[@simp_version.split('.').first, 'X'].join('.')}
          * :output_dir   => path to write SIMP ISO. [Default: './SIMP_ISO']
          * :do_checksum  => Use sha256sum checksum to compare each ISO.  [Default: 'false']
          * :key_name     => Key name to sign packages [Default: 'dev']

        ENV vars:
          - SIMP_BUILD_isos            => Path to the base OS ISO images
          - SIMP_BUILD_distro          => Distribution to build
                                          See '#{File.join(@distro_build_dir, 'build_metadata.yaml')}'}
          - SIMP_BUILD_prompt          => 'no' disables asking questions.
                                          Will default to a full build and *will* erase existing artifacts.
          - SIMP_BUILD_staging_dir     => Path to stage big build assets
                                          [Default: './SIMP_ISO_STAGING']
          - SIMP_BUILD_rm_staging_dir  => 'no' do not forcibly remove the staging dir before starting
          - SIMP_BUILD_overlay         => 'no' uses an existing DVD overlay if found
          - SIMP_BUILD_force_dirty     => 'yes' tries to checks out subrepos even if dirty
          - SIMP_BUILD_docs            => 'yes' builds & includes documentation
          - SIMP_BUILD_checkout        => 'no' will skip the git repo checkouts
          - SIMP_BUILD_bundle          => 'no' skips running bundle in each subrepo
          - SIMP_BUILD_unpack          => 'no' prevents unpacking the source ISO
          - SIMP_BUILD_unpack_merge    => 'no' prevents auto-merging the unpacked ISO
          - SIMP_BUILD_prune           => 'no' passes :prune=>false to iso:build
          - SIMP_BUILD_iso_name        => Renames the output ISO filename [Default: false]
          - SIMP_BUILD_iso_tag         => Appended to the output ISO's filename [Default: false]
          - SIMP_BUILD_update_packages => Automatically update any necessary packages in the packages.yaml file [Default: false]
          - SIMP_BUILD_verbose         => 'yes' enables verbose reporting. [Default: 'no']
          - SIMP_BUILD_signing_key     => The name of the GPG key to use to sign packages. [Default: 'dev']
          - SIMP_BUILD_reposync_only   => 'yes' skips unpacking the locally-build tarball so that you only get items from the reposync directory (if present)
        EOM

        task :auto, [:iso_paths,
                     :release,
                     :output_dir,
                     :do_checksum,
                     :key_name
                    ] do |t, args|

          Simp::Rake::Helpers.check_required_commands(BUILD_REQUIRED_COMMANDS)

          args.with_defaults(
            :iso_paths    => ENV['SIMP_BUILD_isos'] || Dir.pwd,
            :distribution => 'ALL',
            :release      => [@simp_version.split('.').first, 'X'].join('.'),
            :output_dir   => '',
            :do_checksum  => 'false',
            :key_name     => ENV['SIMP_BUILD_signing_key'] || 'dev'
          )

          reposync_only    = ENV.fetch('SIMP_BUILD_reposync_only', 'no') == 'yes'
          iso_paths        = File.expand_path(args[:iso_paths])
          target_release   = args[:release]
          do_checksum      = (args.do_checksum = ~ /^$/ ? 'false' : args.do_checksum)
          key_name         = args[:key_name]
          verbose          = ENV.fetch('SIMP_BUILD_verbose', 'no') == 'yes'
          prompt           = ENV.fetch('SIMP_BUILD_prompt', 'yes') != 'no'
          method           = ENV.fetch('SIMP_BUILD_puppetfile','tracking')
          do_rm_staging    = ENV.fetch('SIMP_BUILD_rm_staging_dir', 'yes') == 'yes'
          build_overlay    = ENV.fetch('SIMP_BUILD_overlay', "yes") == 'yes'
          do_docs          = ENV['SIMP_BUILD_docs'] == 'yes' ? 'true' : 'false'
          do_merge         = ENV['SIMP_BUILD_unpack_merge'] != 'no'
          do_prune         = ENV['SIMP_BUILD_prune'] != 'no' ? 'true' : 'false'
          do_checkout      = ENV['SIMP_BUILD_checkout'] != 'no'
          do_bundle        = ENV['SIMP_BUILD_bundle'] == 'yes' ? true : false
          do_unpack        = ENV['SIMP_BUILD_unpack'] != 'no'
          full_iso_name    = ENV.fetch('SIMP_BUILD_iso_name', false)
          iso_name_tag     = ENV.fetch('SIMP_BUILD_iso_tag', false)

          iso_status = {}

          distro = @build_distro
          version = @build_version
          arch = @build_arch

          tarball          = false
          repo_root_dir    = File.expand_path( @base_dir )

          fail("Cannot Build: No directory '#{@distro_build_dir}' found") unless File.directory?(@distro_build_dir)

          begin
            # For subtask mangling
            $simp6_build_dir = @distro_build_dir
            $simp6_build_metadata = {
              :distro  => distro,
              :version => version,
              :arch    => arch
            }

            output_dir = args[:output_dir].sub(/^$/, File.expand_path( 'SIMP_ISO', @distro_build_dir ))

            staging_dir = ENV.fetch('SIMP_BUILD_staging_dir', File.expand_path( 'SIMP_ISO_STAGING', @distro_build_dir ))

            overlay_dir = File.join(@distro_build_dir, 'DVD_Overlay')

            yaml_file = File.expand_path('release_mappings.yaml', @distro_build_dir)

            tar_file = File.join(overlay_dir, "SIMP-#{@simp_version}-#{distro}-#{version}-#{arch}.tar.gz")

            $simp6_clean_dirs << output_dir
            $simp6_clean_dirs << staging_dir
            $simp6_clean_dirs << overlay_dir

            if File.exist?(tar_file)
              if prompt
                valid_entry = false
                while !valid_entry do
                  puts("Existing tar file found at #{tar_file}")
                  print("Do you want to overwrite it? (y|N): ")

                  resp = $stdin.gets.chomp

                  if resp.empty? || (resp =~ /^(n|N)/)
                    tarball = tar_file
                    valid_entry = true
                  elsif resp =~ /^(y|Y)/
                    tarball = false
                    valid_entry = true

                    if verbose
                      $stderr.puts("Notice: Overwriting existing tarball at #{tar_file}")
                      $stderr.puts("Notice: PRESS CTRL-C WITHIN 5 SECONDS TO CANCEL")
                    end

                    sleep(5)
                  else
                    puts("Invalid input: '#{resp}', please try again")
                  end
                end
              else
                unless (build_overlay)
                  tarball = tar_file
                end
              end
            end

            if tarball
              do_docs     = false
              do_checkout = false
              do_bundle   = false
            end

            @dirty_repos     = nil
            @simp_output_iso = nil

            # Build environment sanity checks
            # --------------------
            if do_rm_staging && !do_unpack
              fail SIMPBuildException, "ERROR: Mixing `SIMP_BUILD_rm_staging_dir=yes` and `SIMP_BUILD_unpack=no` is silly."
            end

            if File.exist?(output_dir) && !File.directory?(output_dir)
              fail SIMPBuildException, "ERROR: ISO output dir exists but is not a directory:\n\n" +
                                       "    '#{output_dir}'\n\n"
            end

            unless File.directory?(output_dir)
              FileUtils.mkdir_p(output_dir)
            end

            # Look up ISOs against known build assets
            # --------------------
            target_data = get_target_data(target_release, iso_paths, yaml_file, do_checksum, verbose )

            # check out subrepos
            # --------------------
            if do_checkout && !tarball
              puts
              puts '='*80
              puts "## Checking out subrepositories"
              puts
              puts "     (skip with `SIMP_BUILD_checkout=no`)"
              puts '='*80

              Dir.chdir repo_root_dir
              Rake::Task['deps:status'].reenable
              Rake::Task['deps:status'].invoke

              if @dirty_repos && !ENV['SIMP_BUILD_force_dirty'] == 'yes'
                raise SIMPBuildException, "ERROR: Dirty repos detected!  I refuse to destroy uncommitted work."
              else
                puts
                puts '-'*80
                puts "#### Checking out subrepositories using method '#{method}'"
                puts '-'*80
                Rake::Task['deps:checkout'].reenable
                Rake::Task['deps:checkout'].invoke(method)
              end

              if do_bundle
                puts
                puts '-'*80
                puts "#### Running bundler in all repos"
                puts '     (Disable with `SIMP_BUILD_bundle=no`)'
                puts '-'*80
                Rake::Task['build:bundle'].reenable
                Rake::Task['build:bundle'].invoke
              else
                puts
                puts '-'*80
                puts "#### SKIPPED: bundler in all repos"
                puts '     (Force with `SIMP_BUILD_bundle=yes`)'
                puts '-'*80
              end
            else
              puts
              puts '='*80
              puts "#### skipping sub repository checkout (because `SIMP_BUILD_checkout=no`)"
              puts
            end

            # build tarball
            # --------------------
            if tarball
              puts
              puts '-'*80
              puts "#### Using pre-existing tarball:"
              puts "           '#{tarball}'"
              puts
              puts '-'*80

            else
              puts
              puts '='*80
              puts "#### Running tar:build"
              puts '='*80

              # Horrible state passing magic vars
              $tarball_tgt = File.join(@distro_build_dir, 'DVD_Overlay', "SIMP-#{@simp_version}-#{distro}-#{version}-#{arch}.tar.gz")

              Rake::Task['tar:build'].reenable
              Rake::Task['tar:build'].invoke(key_name,do_docs)

              tarball = $tarball_tgt
            end

            # yum sync
            # --------------------
            puts
            puts '-'*80
            puts "#### rake build:yum:sync[#{target_data['flavor']},#{target_data['os_version']}]"
            puts '-'*80
            Rake::Task['build:yum:sync'].reenable
            Rake::Task['build:yum:sync'].invoke(target_data['flavor'],target_data['os_version'])

            # If you have previously downloaded packages from yum, you may need to run
            # $ rake build:yum:clean_cache

            # Optionally, you may drop in custom packages you wish to have available during an install into build/yum_data/SIMP<simp_version>_<CentOS or RHEL><os_version>_<architecture>/packages
            # TODO: ENV var for optional packages

            prepare_staging_dir( staging_dir, do_rm_staging, repo_root_dir, verbose )
            Dir.chdir staging_dir

            #
            # --------------------
            if do_unpack
              puts
              puts '='*80
              puts "#### unpack ISOs into staging directory"
              puts "     staging area: '#{staging_dir}'"
              puts
              puts "     (skip with `SIMP_BUILD_unpack=no`)"
              puts '='*80
              puts

              Dir.glob( File.join(staging_dir, "#{target_data['flavor']}*/") ).each do |f|
                FileUtils.rm_f( f , :verbose => verbose )
              end

              target_data['isos'].each do |iso|
                puts "---- rake unpack[#{iso},#{do_merge},#{Dir.pwd},isoinfo,#{target_data['os_version']}#{reposync_only}]"
                Rake::Task['unpack'].reenable
                Rake::Task['unpack'].invoke(iso,do_merge,Dir.pwd,'isoinfo',target_data['os_version'],reposync_only)
              end
            else
              puts
              puts '='*80
              puts "#### skipping ISOs unpack (because `SIMP_BUILD_unpack=no`)"
              puts
            end

            Dir.chdir staging_dir

            puts
            puts '='*80
            puts "#### iso:build[#{tarball}, #{staging_dir}, #{do_prune}]"
            puts '='*80
            puts

            ENV['SIMP_ISO_verbose'] = 'yes' if verbose
            ENV['SIMP_PKG_verbose'] = 'yes' if verbose
            Rake::Task['iso:build'].reenable
            Rake::Task['iso:build'].invoke(tarball,staging_dir,do_prune)

            _isos = Dir[ File.join(staging_dir, 'SIMP-*.iso') ]
            if _isos.size == 0
              fail "ERROR: No SIMP ISOs found in '#{staging_dir}'"
            elsif _isos.size > 1
              warn "WARNING: More than one SIMP ISO found in '#{staging_dir}'"
              _isos.each{ |i| warn i }
            end

            # NOTE: It is possible at this point (given the right
            # `SIMP_BUILD_xxx=no` flags) that iso:build will not have set
            # `@simp_output_iso`.  In that case, look at the ISOs in the staging
            # dir (there should only be one) and take our best guess.
            if @simp_output_iso.nil?
               @simp_output_iso = File.basename(_isos.first)
            end

            output_file = full_iso_name ? full_iso_name : @simp_output_iso
            if iso_name_tag
              output_file = output_file.sub(/\.iso$/i, "__#{iso_name_tag}.iso")
            end

            puts
            puts '='*80
            puts "#### Moving '#{@simp_output_iso}' into:"
            puts "       '#{output_dir}/#{output_file}'"
            puts '='*80
            puts

            iso = File.join(output_dir,output_file)
            FileUtils.mkdir_p File.dirname(iso), :verbose => verbose
            FileUtils.mv(@simp_output_iso, iso, :verbose => verbose)

            var_json = Simp::Packer::IsoVarsJson.new(iso, target_release, target_data, {})
            var_json.write

            puts
            puts '='*80
            puts "#### FINIS!"
            puts '='*80
            puts

            iso_status[[distro, version, arch].join(' ')] = {
              'success' => true
            }

          rescue => e
            iso_status[[distro, version, arch].join(' ')] = {
            'success'   => false,
            'error'     => e.to_s,
            'backtrace' => e.backtrace
            }
          end

          successful_isos = []
          failed_isos = []

          iso_status.keys.each do |iso|
            if iso_status[iso]['success']
              successful_isos << iso
            else
              failed_isos << iso
            end
          end

          unless successful_isos.empty?
            puts '='*80
            puts '='*80
            puts("Successful ISOs:")
            puts(%(  * #{successful_isos.join("\n  * ")}))
          end

          unless failed_isos.empty?
            puts '='*80
            puts("Failed ISOs:")
            failed_isos.each do |iso|
              puts(%(  * #{iso}))
              puts(%(    * Error: #{iso_status[iso]['error']}))

              if verbose
                puts(%(    * Backtrace: #{iso_status[iso]['backtrace'].join("\n")}))
              else
                puts(%(    * Context: #{iso_status[iso]['backtrace'].first}))
              end
            end

            exit(1)
          end
        end
      end

      def get_target_data(target_release, iso_paths, yaml_file, do_checksum, verbose )
        puts '='*80
        puts "## validating ISOs for target:"
        puts "      '#{target_release}' in '#{iso_paths}'"
        puts '='*80
        puts

        mapper          = Simp::Build::ReleaseMapper.new(target_release, yaml_file, do_checksum == 'true')
        mapper.verbose  = true || verbose
        target_data     = mapper.autoscan_unpack_list( iso_paths )

        puts '-'*80
        puts "## target data:"
        puts ''
        puts "     target release: '#{target_release}'"
        puts "     target flavor:  '#{target_data['flavor']}'"
        puts "     source isos:"
        target_data['isos'].each do |iso|
          puts "        - #{iso}"
        end
        puts '-'*80
        puts
        sleep 3

        target_data
      end


      def prepare_staging_dir( staging_dir, do_rm_staging, repo_root_dir, verbose )
        if ['','/',Dir.home,repo_root_dir].include? staging_dir
          fail SIMPBuildException,
               "ERROR: staging directoy path is too stupid to be believed:\n"+
               "         '#{staging_dir}'\n\n" +
               "       Use SIMP_BUILD_staging_dir='path/to/staging/dir'\n\n"
        end

        if do_rm_staging
          puts
          puts '-'*80
          puts '#### Ensuring previous staging directory is removed:'
          puts "       '#{staging_dir}'"
          puts
          puts '     (disable this with `SIMP_BUILD_rm_staging_dir=no`)'
          puts '-'*80

          FileUtils.rm_rf staging_dir, :verbose => verbose
        elsif File.exist? staging_dir
          warn ''
          warn '!'*80
          warn '#### WARNING: staging dir already exists at:'
          warn "              '#{staging_dir}'"
          warn ''
          warn '              - Previously staged assets in this directory may cause problems.'
          warn '              - Use `SIMP_BUILD_rm_staging_dir=yes` to remove it automatically.'
          warn ''
          warn '!'*80
          warn ''
          sleep 10
        end
        FileUtils.mkdir_p staging_dir, :verbose => verbose
      end


    end
  end
end
