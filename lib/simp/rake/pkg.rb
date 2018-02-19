# This file provided many common build-related tasks and helper methods from
# the SIMP Rakefile ecosystem.

require 'rake'
require 'rake/clean'
require 'rake/tasklib'
require 'fileutils'
require 'find'
require 'simp/relchecks'
require 'simp/rpm'
require 'simp/rake/helpers/rpm_spec'

module Simp; end
module Simp::Rake
  class Pkg < ::Rake::TaskLib

    include Simp::Rake::Helpers::RPMSpec

    # path to the project's directory.  Usually `File.dirname(__FILE__)`
    attr_accessor :base_dir

    # the name of the package.  Usually `File.basename(@base_dir)`
    attr_accessor :pkg_name

    # path to the project's RPM specfile
    attr_accessor :spec_file

    # path to the directory to place generated assets (e.g., rpm, tar.gz)
    attr_accessor :pkg_dir

    # array of items to exclude from the tarball
    attr_accessor :exclude_list

    # array of items to additionally clean
    attr_accessor :clean_list

    # array of items to ignore when checking if the tarball needs to be rebuilt
    attr_accessor :ignore_changes_list

    attr_reader   :spec_info

    def initialize( base_dir, unique_namespace = nil, simp_version=nil )
      @base_dir            = base_dir
      @pkg_name            = File.basename(@base_dir)
      @pkg_dir             = File.join(@base_dir, 'dist')
      @pkg_tmp_dir         = File.join(@pkg_dir, 'tmp')
      @exclude_list        = [ File.basename(@pkg_dir) ]
      @clean_list          = []
      @ignore_changes_list = [
        'Gemfile.lock',
        'dist/logs',
        'dist/tmp',
        'dist/*.rpm',
        'dist/rpmbuild',
        'spec/fixtures/modules'
      ]
      @verbose = ENV.fetch('SIMP_RAKE_PKG_verbose','no') == 'yes'

      # This is only meant to be used to work around the case where particular
      # packages need to ignore some set of artifacts that get updated out of
      # band. This should not be set as a regular environment variable and
      # should be fixed properly at some time in the future.
      #
      # Presently, this is used by simp-doc
      if ENV['SIMP_INTERNAL_pkg_ignore']
        @ignore_changes_list += ENV['SIMP_INTERNAL_pkg_ignore'].split(',')
      end

      FileUtils.mkdir_p(@pkg_tmp_dir)

      local_spec = Dir.glob(File.join(@base_dir, 'build', '*.spec'))
      unless local_spec.empty?
        @spec_file = local_spec.first
      else
        @spec_tempfile = File.open(File.join(@pkg_tmp_dir, "#{@pkg_name}.spec"), 'w')
        @spec_tempfile.write(rpm_template(simp_version))

        @spec_file = @spec_tempfile.path

        @spec_tempfile.flush
        @spec_tempfile.close

        FileUtils.chmod(0640, @spec_file)
      end

      ::CLEAN.include( @pkg_dir )

      yield self if block_given?

      ::CLEAN.include( @clean_list )

      if unique_namespace
        namespace unique_namespace.to_sym do
          define
        end
      else
        define
      end
    end

    def define
      # For the most part, we don't want to hear Rake's noise, unless it's an error
      # TODO: Make this configurable
      verbose(false)

      define_clean
      define_clobber
      define_pkg_tar
      define_pkg_rpm
      define_pkg_check_version
      define_pkg_compare_latest_tag
      define_pkg_create_tag_changelog
      task :default => 'pkg:tar'

      Rake::Task['pkg:tar']
      Rake::Task['pkg:rpm']

      self
    end

    # Ensures that the correct file names are used across the board.
    def initialize_spec_info
      unless @spec_info
        # This gets the resting spec file and allows us to pull out the name
        @spec_info ||= Simp::RPM.new(@spec_file)
        @spec_info_dir ||= @base_dir

        @dir_name ||= "#{@spec_info.basename}-#{@spec_info.version}"
        @full_pkg_name ||= "#{@dir_name}-#{@spec_info.release}"

        _rpmbuild_srcdir = `rpm -E '%{_sourcedir}'`.strip

        unless File.exist?(_rpmbuild_srcdir)
          sh 'rpmdev-setuptree'
        end

        @rpm_srcdir ||= "#{@pkg_dir}/rpmbuild/SOURCES"
        FileUtils.mkdir_p(@rpm_srcdir)

        @tar_dest ||= "#{@pkg_dir}/#{@full_pkg_name}.tar.gz"

        if @full_pkg_name =~ /UNKNOWN/
          fail("Error: Could not determine package information from 'metadata.json'. Got '#{@full_pkg_name}'")
        end
      end
    end

    def define_clean
      desc <<-EOM
      Clean build artifacts for #{@pkg_name}
      EOM
      task :clean do |t,args|
        # this is provided by 'rake/clean' and the ::CLEAN constant
      end
    end

    def define_clobber
      desc <<-EOM
      Clobber build artifacts for #{@pkg_name}
      EOM
      task :clobber do |t,args|
      end
    end

    def define_pkg_tar
      namespace :pkg do
        directory @pkg_dir

        task :initialize_spec_info => [@pkg_dir] do |t,args|
          initialize_spec_info
        end

        # :pkg:tar
        # -----------------------------
        desc <<-EOM
        Build the #{@pkg_name} tar package.
        EOM
        task :tar => [:initialize_spec_info] do |t,args|
          target_dir = File.basename(@base_dir)

          Dir.chdir(%(#{@base_dir}/..)) do
            require_rebuild = false

            if File.exist?(@tar_dest)
              Find.find(target_dir) do |path|
                filename = File.basename(path)

                Find.prune if filename =~ /^\./
                Find.prune if ((filename == File.basename(@pkg_dir)) && File.directory?(path))

                to_ignore = @ignore_changes_list.map{|x| x = Dir.glob(File.join(@base_dir, x))}.flatten
                Find.prune if to_ignore.include?(File.expand_path(path))

                next if File.directory?(path)

                if require_rebuild?(@tar_dest, path)
                  require_rebuild = true
                  break
                end
              end
            else
              require_rebuild = true
            end

            if require_rebuild
              sh %Q(tar --owner 0 --group 0 --exclude-vcs --exclude=#{@exclude_list.join(' --exclude=')} --transform='s/^#{@pkg_name}/#{@dir_name}/' -cpzf "#{@tar_dest}" #{@pkg_name})
            end
          end
        end
      end
    end

    def define_pkg_rpm
      namespace :pkg do
        desc <<-EOM
        Build the #{@pkg_name} RPM.

            By default, the package will be built to support a SIMP-6.X file structure.
            To build the package for a different version of SIMP, export SIMP_BUILD_version=<5.X,4.X>
        EOM
        task :rpm => [:tar] do |t,args|
          rpm_opts = [
            %(-D 'buildroot #{@pkg_dir}/rpmbuild/BUILDROOT'),
            %(-D 'builddir #{@pkg_dir}/rpmbuild/BUILD'),
            %(-D '_sourcedir #{@rpm_srcdir}'),
            %(-D '_rpmdir #{@pkg_dir}'),
            %(-D '_srcrpmdir #{@pkg_dir}'),
            %(-D '_build_name_fmt %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm')
          ]
          rpm_opts << '-v' if @verbose
          rpm_opts << "-D 'lua_debug 1'" if (ENV.fetch('SIMP_RAKE_PKG_LUA_debug','no') =='yes')

          Dir.chdir(@pkg_dir) do

            # Copy in the materials required for the module builds
            # The following are required to build successful RPMs using
            # the new LUA-based RPM template
            puppet_module_info_files = [
              Dir.glob(%(#{@base_dir}/build/rpm_metadata/*)),
              %(#{@base_dir}/CHANGELOG),
              %(#{@base_dir}/metadata.json)
            ].flatten

            puppet_module_info_files.each do |f|
              if File.exist?(f)
                FileUtils.cp_r(f, @rpm_srcdir)
              end
            end

            # Link in any misc artifacts that got dumped into 'dist' by other code
            extra_deps = Dir.glob("*")
            extra_deps.delete_if{|x| x =~ /(\.rpm$|(^(rpmbuild|logs|tmp$)))/}

            Dir.chdir(@rpm_srcdir) do
              extra_deps.each do |dep|
                unless File.exist?(dep)
                  FileUtils.cp_r("../../#{dep}", dep)
                end
              end
            end

            FileUtils.mkdir_p('logs')
            FileUtils.mkdir_p('rpmbuild/BUILDROOT')
            FileUtils.mkdir_p('rpmbuild/BUILD')

            srpms = [@full_pkg_name + '.src.rpm']
            if require_rebuild?(srpms.first, @tar_dest)
              # Need to build the SRPM so that we can get the build dependencies
              cmd = %(rpmbuild #{rpm_opts.join(' ')} -bs #{@spec_file} > logs/build.out 2> logs/build.err)
              puts "==== SRPM BUILD ====: #{cmd}" if @verbose
              %x(#{cmd})

              srpms = File.read('logs/build.out').scan(%r(Wrote:\s+(.*\.rpm))).flatten

              if srpms.empty?
                raise <<-EOM
  Could not create SRPM for '#{@spec_info.basename}
    Error: #{File.read('logs/build.err')}
                EOM
              end
            end

            # Collect the built, or downloaded, RPMs
            rpms = []

            @spec_info.packages
            expected_rpms = @spec_info.packages.map{|f|
              latest_rpm = Dir.glob("#{f}-#{@spec_info.version}*.rpm").select{|x|
                # Get all local RPMs that are not SRPMs
                x !~ /\.src\.rpm$/
              }.map{|x|
                # Convert them to objects
                x = Simp::RPM.new(x)
              }.sort_by{|x|
                # Sort by the full version of the package and return the one
                # with the highest version
                Gem::Version.new(x.full_version)
              }.last

              if latest_rpm && (
                  Gem::Version.new(latest_rpm.full_version) >=
                  Gem::Version.new(@spec_info.full_version)
              )
                f = latest_rpm.rpm_name
              else
                f = "#{f}-#{@spec_info.full_version}-#{@spec_info.arch}.rpm"
              end
            }

            if expected_rpms.empty? || require_rebuild?(expected_rpms, srpms)

              expected_rpms_data = expected_rpms.map{ |f|
                if File.exist?(f)
                  f = Simp::RPM.new(f)
                else
                  f = nil
                end
              }

              require_rebuild = true

              # We need to rebuild if not *all* of the expected RPMs are present
              unless expected_rpms_data.include?(nil)
                # If all of the RPMs are signed, we do not need a rebuild
                require_rebuild = !expected_rpms_data.compact.select{|x| !x.signature}.empty?
              end

              if !require_rebuild
                # We found all expected RPMs and they all had valid signatures
                #
                # Record the existing RPM metadata in the output file
                rpms = expected_rpms
              else
                # Try a build
                cmd = %(rpmbuild #{rpm_opts.join(' ')} --rebuild #{srpms.first} > logs/build.out 2> logs/build.err)
                puts "======== #{cmd}" if @verbose
                %x(#{cmd})

                # If the build failed, it was probably due to missing dependencies
                unless $?.success?
                  # Find the RPM build dependencies
                  rpm_build_deps = %x(rpm -q -R -p #{srpms.first}).strip.split("\n")

                  # RPM stuffs this in every time
                  rpm_build_deps.delete_if {|x| x =~ /^rpmlib/}

                  # See if we have the ability to install things
                  unless Process.uid == 0
                    unless %x(sudo -ln) =~ %r(NOPASSWD:\s+(ALL|yum( install)?))
                      raise <<-EOM
    Please install the following dependencies and try again:
    #{rpm_build_deps.map{|x| x = "  * #{x}"}.join("\n")}
    EOM
                    end
                  end

                  rpm_build_deps.map! do |rpm|
                    if rpm =~ %r((.*)\s+(?:<=|=|==)\s+(.+))
                      rpm = "#{$1}-#{$2}"
                    end

                    rpm.strip
                  end

                  yum_install_cmd = %(yum -y install '#{rpm_build_deps.join("' '")}')
                  unless Process.uid == 0
                    yum_install_cmd = 'sudo ' + yum_install_cmd
                  end

                  install_output = %x(#{yum_install_cmd} 2>&1)

                  if !$?.success? || (install_output =~ %r((N|n)o package))
                    raise <<-EOM
    Could not run #{yum_install_cmd}
      Error: #{install_output}
                    EOM
                  end
                end

                # Try it again!
                #
                # If this doesn't work, something we can't fix automatically is wrong
                cmd = %(rpmbuild #{rpm_opts.join(' ')} --rebuild #{srpms.first} > logs/build.out 2> logs/build.err)
                puts "======== #{cmd}" if @verbose
                %x(#{cmd})

                rpms = File.read('logs/build.out').scan(%r(Wrote:\s+(.*\.rpm))).flatten - srpms

                if rpms.empty?
                  raise <<-EOM
    Could not create RPM for '#{@spec_info.basename}
      Error: #{File.read('logs/build.err')}
                  EOM
                end
              end

              # Prevent overwriting the last good metadata file
              raise %(Could not find any valid RPMs for '#{@spec_info.basename}') if rpms.empty?

              Simp::RPM.create_rpm_build_metadata(File.expand_path(@base_dir), srpms, rpms)
            end
          end
        end
      end
    end

    def define_pkg_check_version
      namespace :pkg do
        # :pkg:check_version
        # -----------------------------
        desc <<-EOM
        Ensure that #{@pkg_name} has a properly updated version number.
        EOM
        task :check_version do |t,args|
          require 'json'

          # Get the current version
          if File.exist?('metadata.json')
            mod_version = JSON.load(File.read('metadata.json'))['version'].strip
            success_msg = "#{@pkg_name}: Version #{mod_version} up to date"

            # If we have no tags, we need a new version
            if %x(git tag).strip.empty?
              puts "#{@pkg_name}: New Version Required"
            else
              # See if the module is newer than all tags
              matching_tag = %x(git tag --points-at HEAD).strip.split("\n").first

              if matching_tag.nil? || matching_tag.empty?
                # We don't have a matching release
                # Get the closest tag
                nearest_tag = %x(git describe --abbrev=0 --tags).strip

                if mod_version == nearest_tag
                  puts "#{@pkg_name}: Error: metadata.json needs to be updated past #{mod_version}"
                else
                  # Check the CHANGELOG Version
                  if File.exist?('CHANGELOG')
                    changelog = File.read('CHANGELOG')
                    changelog_version = nil

                    # Find the first date line
                    changelog.each_line do |line|
                      if line =~ /\*.*(\d+\.\d+\.\d+)(-\d+)?\s*$/
                        changelog_version = $1
                        break
                      end
                    end

                    if changelog_version
                      if changelog_version == mod_version
                        puts success_msg
                      else
                        puts "#{@pkg_name}: Error: CHANGELOG version #{changelog_version} out of date for version #{mod_version}"
                      end
                    else
                      puts "#{@pkg_name}: Error: No CHANGELOG version found"
                    end
                  else
                    puts "#{@pkg_name}: Warning: No CHANGELOG found"
                  end
                end
              else
                if mod_version != matching_tag
                  puts "#{@pkg_name}: Error: Tag #{matching_tag} does not match version #{mod_version}"
                else
                  puts success_msg
                end
              end
            end
          else
            puts "#{@pkg_name}: No metadata.json found"
          end
        end
      end
    end

    def define_pkg_compare_latest_tag
      namespace :pkg do
        desc <<-EOM
        Compare to latest tag.
          ARGS:
            * :tags_source => Set to the remote from which the tags for this
                              project can be fetched. Defaults to 'origin'.
            * :verbose => Set to 'true' if you want to see detailed messages

          NOTES:
          Compares mission-impacting (significant) files with the latest
          tag and identifies the relevant files that have changed.

          Fails if
          (1) There is any version validation or changelog parsing failure
              that would prevent an annotated changelog tag from being
              created. (See pkg::create_tag_changelog)
          (2) A version bump is required but not recorded in both the
              CHANGELOG and metadata.json files.
          (3) The latest version is < latest tag.

          Changes to the following files/directories are not considered
          significant:
          - Any hidden file/directory (entry that begins with a '.')
          - Gemfile
          - Gemfile.lock
          - Rakefile
          - spec directory
          - doc directory
        EOM
        task :compare_latest_tag, [:tags_source, :verbose] do |t,args|
          tags_source = args[:tags_source].nil? ? 'origin' : args[:tags_source]
          if args[:verbose].to_s == 'true'
            verbose = true
          else
            verbose = false
          end
          Simp::RelChecks::compare_latest_tag(@base_dir, tags_source, verbose)
        end
      end
    end

    def define_pkg_create_tag_changelog
      namespace :pkg do
        # :pkg:create_tag_changelog
        # -----------------------------
        desc <<-EOM
        Generate an appropriate changelog for an annotated tag from a
        component's CHANGELOG or RPM spec file.

        The changelog text will be for the latest version and contain
        1 or more changelog entries for that version, in reverse
        chronological order.

        ARGS:
          * verbose => Set to 'true' if you want to see
            non-catestrophic warning messages.

        NOTES:
          * Changelog entries must follow the following rules:
            - An entry must start with * and be terminated
              by a blank line.
            - The first line must be of the form
              * Wed Jul 05 2017 Author Name <author@simp.com> - 1.2.3-4
            - The date string must be RPM compatible.
            - Dates must be in reverse chronological order, with the
              newest dates occurring at the top of the changelog.
            - Both an author name and email are required.
            - The author email must be contained in < >.
            - The version is required and must be of the form
              <major>.<minor>.<patch>.
            - The version may contain a release qualifier.
            - When the release qualifier is present, it must appear
              at the end of the version string and be separated from
              the version by a '-'.

          * This task will fail if any of the following occur:
            - The metadata.json file for a Puppet module component
              cannot be parsed.
            - The CHANGELOG file for a Puppet module component does
              not exist.
            - The CHANGELOG entries for the latest version are
              malformed.
            - The RPM spec file or a non-Puppet module component does
              not exist.
            - More than 1 RPM spec file for a non-Puppet module
              component exists.
            - No valid changelog entries for the version specified in
              the metadata.json/spec file are found.
            - The latest changelog version is greater than the version
              in the metadata.json or the RPM spec file.
            - The RPM release specified in the spec file does not match
              the release in a changelog entry for the version.
            - Any changelog entry below the first entry has a version
              greater than that of the first entry.
            - The changelog entries for the latest version are out of
              date order.
            - The weekday for a changelog entry for the latest version
              does not match the date specified.

        EOM
        task :create_tag_changelog, [:verbose] do |t,args|
          if args[:verbose].to_s == 'true'
            verbose = true
          else
            verbose = false
          end
          puts Simp::RelChecks::create_tag_changelog(@base_dir, verbose)
        end
      end
    end

    # ------------------------------------------------------------------------------
    # helper methods
    # ------------------------------------------------------------------------------
    # Return True if any of the 'old' Array are newer than the 'new' Array
    def require_rebuild?(new, old)
      return true if ( Array(old).empty? || Array(new).empty?)

      Array(new).each do |new_file|
        return true unless File.exist?(new_file)

        return true unless uptodate?(new_file, Array(old))
      end

      return false
    end
  end
end
