# This file provided many common build-related tasks and helper methods from
# the SIMP Rakefile ecosystem.

require 'rake'
require 'rake/clean'
require 'rake/tasklib'
require 'fileutils'
require 'find'
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
        'spec/fixtures/modules',
        'build/rpm_metadata',          # this is generated
        'build/rpm_metadata/requires'  # this is generated
      ]

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

      # The following are required to build successful RPMs using the new
      # LUA-based RPM template

      @puppet_module_info_files = [
        Dir.glob(%(#{@base_dir}/build/rpm_metadata/*)),
        %(#{@base_dir}/CHANGELOG),
        %(#{@base_dir}/metadata.json)
      ].flatten

      # Workaround for CentOS system builds
      dist = `rpm -E '%{dist}'`.strip.gsub('.centos','')
      dist_macro = %(%dist #{dist})

      rpmmacros = [dist_macro]

      rpmmacros_file = File.join(ENV['HOME'], '.rpmmacros')

      if File.exist?(rpmmacros_file)
        rpmmacros = File.read(rpmmacros_file).split("\n")

        dist_index = rpmmacros.each_index.select{|i| rpmmacros[i] =~ /^%dist\s+/}.first

        if dist_index
          rpmmacros[dist_index] = dist_macro
        else
          rpmmacros << dist_macro
        end
      end

      File.open(rpmmacros_file, 'w') do |fh|
        fh.puts rpmmacros.join("\n")
        fh.flush
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
      task :default => 'pkg:tar'

      Rake::Task['pkg:tar']
      Rake::Task['pkg:rpm']

      self
    end

    # Ensures that the correct file names are used across the board.
    def initialize_spec_info
      unless @spec_info
        # This gets the resting spec file and allows us to pull out the name
        @spec_info   = Simp::RPM.get_info(@spec_file)
        @spec_info_dir = @base_dir

        @dir_name       = "#{@spec_info[:name]}-#{@spec_info[:version]}"
        @full_pkg_name = "#{@dir_name}-#{@spec_info[:release]}"

        _rpmbuild_srcdir = `rpm -E '%{_sourcedir}'`.strip

        unless File.exist?(_rpmbuild_srcdir)
          sh 'rpmdev-setuptree'
        end

        @rpm_srcdir = "#{@pkg_dir}/rpmbuild/SOURCES"
        FileUtils.mkdir_p(@rpm_srcdir)

        @tar_dest = "#{@pkg_dir}/#{@full_pkg_name}.tar.gz"

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

          Dir.chdir(@pkg_dir) do

            # Copy in the materials required for the module builds
            @puppet_module_info_files.each do |f|
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
              %x(rpmbuild #{rpm_opts.join(' ')} -bs #{@spec_file} > logs/build.out 2> logs/build.err)

              srpms = File.read('logs/build.out').scan(%r(Wrote:\s+(.*\.rpm))).flatten

              if srpms.empty?
                raise <<-EOM
  Could not create SRPM for '#{@spec_info[:name]}
    Error: #{File.read('logs/build.err')}
                EOM
              end
            end

            existing_rpm = Dir.glob(@full_pkg_name + '.*.rpm')
            existing_rpm.delete_if{|x| x =~ /src.rpm$/}

            if existing_rpm.empty? || require_rebuild?(existing_rpm.first, srpms)

              # Try a build
              %x(rpmbuild #{rpm_opts.join(' ')} --rebuild #{srpms.first} > logs/build.out 2> logs/build.err)

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

                  rpm
                end

                yum_install_cmd = %(yum -y install #{rpm_build_deps.join(' ')})
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
              %x(rpmbuild #{rpm_opts.join(' ')} --rebuild #{srpms.first} > logs/build.out 2> logs/build.err)

              rpms = File.read('logs/build.out').scan(%r(Wrote:\s+(.*\.rpm))).flatten - srpms

              if rpms.empty?
                raise <<-EOM
  Could not create RPM for '#{@spec_info[:name]}
    Error: #{File.read('logs/build.err')}
                EOM
              end

              # Update the dist/.last_rpm_build_metadata file
              last_build = {
                'git_hash' => %x(git rev-list --max-count=1 HEAD).chomp,
                'srpms'    => {},
                'rpms'     => {}
              }

              srpms.each do |srpm|
                file_stat = File.stat(srpm)

                last_build['srpms'][File.basename(srpm)] = {
                  'metadata'  => Simp::RPM.get_info(srpm),
                  'size'      => file_stat.size,
                  'timestamp' => file_stat.mtime,
                  'path'      => File.absolute_path(srpm)
                }
              end

              rpms.each do |rpm|
                file_stat = File.stat(rpm)

                last_build['rpms'][File.basename(rpm)] = {
                  'metadata' => Simp::RPM.get_info(rpm),
                  'size'      => file_stat.size,
                  'timestamp' => file_stat.mtime,
                  'path'     => File.absolute_path(rpm)
                }
              end

              File.open('logs/last_rpm_build_metadata.yaml','w') do |fh|
                fh.puts(last_build.to_yaml)
              end
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
