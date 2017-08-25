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

    # path to the directory to place generated assets (e.g., rpm, srpm, tar.gz)
    attr_accessor :pkg_dir

    # array of items to exclude from the tarball
    attr_accessor :exclude_list

    # array of items to additionally clean
    attr_accessor :clean_list

    # array of items to ignore when checking if the tarball needs to be rebuilt
    attr_accessor :ignore_changes_list

    attr_reader   :spec_info

    def initialize( base_dir, unique_name=nil, unique_namespace=nil, simp_version=nil )
      @base_dir            = base_dir
      @pkg_name            = File.basename(@base_dir)
      @pkg_dir             = File.join(@base_dir, 'dist')
      @pkg_tmp_dir         = File.join(@pkg_dir, 'tmp')
      @pkg_stash_dir       = File.join(@pkg_tmp_dir, '.stash')
      @exclude_list        = [ File.basename(@pkg_dir) ]
      @clean_list          = []
      @ignore_changes_list = [
        'Gemfile.lock',
        'spec/fixtures/modules',
        'build/rpm_metadata',          # this is generated
        'build/rpm_metadata/requires'  # this is generated
      ]
      @chroot_name         = unique_name

      local_spec = Dir.glob(File.join(@base_dir, 'build', '*.spec'))
      unless local_spec.empty?
        @spec_file = local_spec.first
      else
        FileUtils.mkdir_p(@pkg_stash_dir) unless File.directory?(@pkg_stash_dir)

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
        @spec_file,
        %(#{@base_dir}/build),
        %(#{@base_dir}/CHANGELOG),
        %(#{@base_dir}/metadata.json)
      ]

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
      define_pkg_srpm
      define_pkg_rpm
      define_pkg_scrub
      define_pkg_check_version
      task :default => 'pkg:tar'

      Rake::Task['pkg:tar'].enhance(['pkg:restore_stash'])
      Rake::Task['pkg:srpm'].enhance(['pkg:restore_stash'])
      Rake::Task['pkg:rpm'].enhance(['pkg:restore_stash'])

      self
    end

    # Add a file to the pkg stash
    # These will be restored to the @pkg_dir at the end of the run
    def stash(file)
      FileUtils.mv(file, @pkg_stash_dir)
    end

    # Restore everything from the stash dir
    def restore_stash
      Dir.glob(File.join(@pkg_stash_dir, '*')).each do |file|
        FileUtils.mv(file, @pkg_dir)
      end
    end

    # Initialize the mock space if passed and retrieve the spec info from that
    # space directly.
    #
    # Ensures that the correct file names are used across the board.
    def initialize_spec_info(chroot, unique='false')
      unless @spec_info
        # This gets the resting spec file and allows us to pull out the name
        @spec_info   = Simp::RPM.get_info(@spec_file)
        @spec_info_dir = @base_dir

        if chroot
          @chroot_name = @chroot_name || "#{@spec_info[:name]}__#{ENV.fetch( 'USER', 'USER' )}"

          if ENV['SIMP_PKG_rand_name'] && (ENV['SIMP_PKG_rand_name'] != 'no')
            @chroot_name = @chroot_name + '__' + Time.now.strftime('%s%L')
          end

          if @spec_info[:has_dist_tag]
            mock_cmd = mock_pre_check( chroot, @chroot_name, unique ) + " --root #{chroot}"

            # Need to do this in case there is already a directory in /tmp
            rand_dirname = (0...10).map { ('a'..'z').to_a[rand(26)] }.join
            rand_tmpdir = %(/tmp/#{rand_dirname}_tmp)

            # Hack to work around the fact that we have conflicting '-D' entries
            # TODO: Refactor this
            mock_cmd = mock_cmd.split(/-D '.*?'/).join
            mock_cmd = "#{mock_cmd} -D 'pup_module_info_dir #{rand_tmpdir}'"

            sh %Q(#{mock_cmd} --chroot 'mkdir -p #{rand_tmpdir}')

            @puppet_module_info_files.each do |copy_in|
              if File.exist?(copy_in)
                sh %Q(#{mock_cmd} --copyin #{copy_in} #{rand_tmpdir})
              end
            end

            sh %Q(#{mock_cmd} --chroot 'chmod -R ugo+rwX #{rand_tmpdir}')

            info_hash = {
              :command    => %Q(#{mock_cmd} --chroot --cwd='#{rand_tmpdir}'),
              :rpm_extras => %(--specfile #{rand_tmpdir}/#{File.basename(@spec_file)} )
            }

            @spec_info = Simp::RPM.get_info(@spec_file, info_hash)
          end
        end

        @dir_name       = "#{@spec_info[:name]}-#{@spec_info[:version]}"
        _full_pkg_name = "#{@dir_name}-#{@spec_info[:release]}"
        @full_pkg_name  = _full_pkg_name.gsub("%{?snapshot_release}","")
        @tar_dest       = "#{@pkg_dir}/#{@full_pkg_name}.tar.gz"

        if @tar_dest =~ /UNKNOWN/
          fail("Error: Could not determine package information from 'metadata.json'. Got '#{File.basename(@tar_dest)}'")
        end
      end
    end

    def define_clean
      desc <<-EOM
      Clean build artifacts for #{@pkg_name} (except for mock)
      EOM
      task :clean do |t,args|
        # this is provided by 'rake/clean' and the ::CLEAN constant
      end
    end

    def define_clobber
      desc <<-EOM
      Clobber build artifacts for #{@pkg_name} (except for mock)
      EOM
      task :clobber do |t,args|
      end
    end

    def define_pkg_tar
      namespace :pkg do
        directory @pkg_dir

        task :restore_stash do |t,args|
          at_exit { restore_stash }
        end

        task :initialize_spec_info,[:chroot,:unique] => [@pkg_dir] do |t,args|
          args.with_defaults(:chroot => nil)
          args.with_defaults(:unique => false)

          initialize_spec_info(args[:chroot], args[:unique])
        end

        # :pkg:tar
        # -----------------------------
        desc <<-EOM
        Build the #{@pkg_name} tar package.
            * :snapshot_release - Add snapshot_release (date and time) to rpm
                                  version, rpm spec file must have macro for
                                  this to work.
        EOM
        task :tar,[:chroot,:unique,:snapshot_release] => [:initialize_spec_info] do |t,args|
          args.with_defaults(:snapshot_release => 'false')
          args.with_defaults(:chroot => nil)
          args.with_defaults(:unique => 'false')

          l_date = ''
          if args[:snapshot_release] == 'true'
            l_date = '.' + "#{TIMESTAMP}"
            @tar_dest = "#{@pkg_dir}/#{@full_pkg_name}#{l_date}.tar.gz"
          end

          # Remove any tar files that are not from this version
          tar_files = Dir.glob(%(#{@pkg_dir}/#{@spec_info[:name]}-#{@spec_info[:version]}*.tar.gz))
          tar_files.delete(@tar_dest)
          tar_files.each do |tf|
            stash(tf)
          end

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

                unless uptodate?(@tar_dest,[path])
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

    def define_pkg_srpm
      namespace :pkg do
        desc <<-EOM
        Build the #{@pkg_name} SRPM.
          Building RPMs requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
            * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1)."
            * :unique - Whether or not to build the SRPM in a unique Mock environment.
                        This can be very useful for parallel builds of all modules.
            * :snapshot_release - Add snapshot_release (date and time) to rpm version.
                        Rpm spec file must have macro for this to work.

            By default, the package will be built to support a SIMP-6.X file structure.
            To build the package for a different version of SIMP, export SIMP_BUILD_version=<5.X,4.X>
       EOM
        task :srpm,[:chroot,:unique,:snapshot_release] => [:tar] do |t,args|
          args.with_defaults(:unique => 'false')
          args.with_defaults(:snapshot_release => 'false')

          l_date = ''
          if args[:snapshot_release] == 'true'
            l_date = '.' + "#{TIMESTAMP}"
            mocksnap = "-D 'snapshot_release #{l_date}'"
            @tar_dest = "#{@pkg_dir}/#{@full_pkg_name}#{l_date}.tar.gz"
          end

          srpms = Dir.glob(%(#{@pkg_dir}/#{@spec_info[:name]}*-#{@spec_info[:version]}-*#{l_date}*.src.rpm))

          # Get rid of any SRPMs that are not of this distribution build if we
          # have found one
          if @spec_info[:dist_tag]
            srpms.delete_if do |srpm|
              if srpm.split(@spec_info[:dist_tag]).last != '.src.rpm'
                if File.exist?(srpm)
                  stash(srpm)
                end

                true
              else
                false
              end
            end
          end

          if require_rebuild?(srpms, @tar_dest)

            mock_cmd = mock_pre_check( args[:chroot], @chroot_name, args[:unique] )

            @puppet_module_info_files.each do |file|
              next unless File.exist?(file)

              Find.find(file) do |path|
                next if File.directory?(path)

                tgt_file = File.join(@pkg_dir, File.basename(path))
                FileUtils.remove_entry_secure(tgt_file) if File.exist?(tgt_file)
                FileUtils.cp(path, @pkg_dir) if File.exist?(path)
              end
            end

            cmd = %Q(#{mock_cmd} --root #{args[:chroot]} #{mocksnap} --buildsrpm --spec #{@spec_file} --sources #{@pkg_dir})

            sh cmd
          end
        end
      end
    end

    def define_pkg_rpm
      namespace :pkg do
        desc <<-EOM
        Build the #{@pkg_name} RPM.
          Building RPMs requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
            * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1)."
            * :unique - Whether or not to build the RPM in a unique Mock environment.
                        This can be very useful for parallel builds of all modules.
            * :snapshot_release - Add snapshot_release (date and time) to rpm version.
                        Rpm spec file must have macro for this to work.

            By default, the package will be built to support a SIMP-6.X file structure.
            To build the package for a different version of SIMP, export SIMP_BUILD_version=<5.X,4.X>
        EOM
        task :rpm,[:chroot,:unique,:snapshot_release] => [:srpm] do |t,args|
          args.with_defaults(:unique => 'false')
          args.with_defaults(:snapshot_release => 'false')

          l_date = ''
          if args[:snapshot_release] == 'true'
            l_date = '.' + "#{TIMESTAMP}"
            mocksnap = "-D 'snapshot_release #{l_date}'"
            @tar_dest = "#{@pkg_dir}/#{@full_pkg_name}#{l_date}.tar.gz"
          end

          rpms = Dir.glob(%(#{@pkg_dir}/#{@spec_info[:name]}-*#{@spec_info[:version]}-*#{l_date}*.rpm))

          srpms = rpms.select{|x| x =~ /src\.rpm$/}
          rpms = (rpms - srpms)

          # Get rid of any RPMs that are not of this distribution build if we
          # have found one
          if @spec_info[:dist_tag]
            rpms.delete_if do |rpm|
              if rpm.split(@spec_info[:dist_tag]).last != ".#{@spec_info[:arch]}.rpm"
                if File.exist?(rpm)
                  stash(rpm)
                end

                true
              else
                false
              end
            end
          end

          srpms.each do |srpm|
            dirname = File.dirname(srpm)
            basename = File.basename(srpm,'.src.rpm')
            srpm_info = Simp::RPM.get_info(srpm)

            rpm = [File.join(dirname, basename), srpm_info[:arch], 'rpm'].join('.')
            if require_rebuild?(rpm, srpm)
              mock_cmd = mock_pre_check(args[:chroot], @chroot_name, args[:unique])

              cmd = %Q(#{mock_cmd} --root #{args[:chroot]} #{mocksnap} #{srpm})

              sh cmd

              # remote chroot unless told not to (saves LOTS of space during ISO builds)
              unless ENV['SIMP_RAKE_MOCK_cleanup'] == 'no'
                cmd = %Q(#{mock_cmd} --root #{args[:chroot]} --clean)
                sh cmd
              end
            end
          end
        end
      end
    end

    def define_pkg_scrub
      namespace :pkg do
        # :pkg:scrub
        # -----------------------------
        desc <<-EOM
        Scrub the #{@pkg_name} mock build directory.
        EOM
        task :scrub,[:chroot,:unique] do |t,args|
          args.with_defaults(:unique => 'false')

          mock_cmd = mock_pre_check( args[:chroot], @chroot_name, args[:unique], false )
          cmd = %Q(#{mock_cmd} --scrub=all)
          sh cmd
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
    # Get a list of all of the mock configs available on the system.
    def Pkg.get_mock_configs
      Dir.glob('/etc/mock/*.cfg').sort.map{ |x| x = File.basename(x,'.cfg')}
    end

    # Return True if any of the 'old' Array are newer than the 'new' Array
    def require_rebuild?(new, old)
      return true if ( Array(old).empty? || Array(new).empty?)

      Array(new).each do |new_file|
        unless File.exist?(new_file)
          return true
        end

        unless uptodate?(new_file, Array(old))
          return true
        end
      end

      return false
    end

    # Run some pre-checks to make sure that mock will work properly.
    #
    # chroot   = name of mock chroot to use
    # unique_ext = TODO
    # Pass init=false if you do not want the function to initialize.
    #
    # Returns a String that contains the appropriate mock command.
    def mock_pre_check( chroot, unique_ext, unique='false', init=true )

      mock = ENV['mock'] || '/usr/bin/mock'

      raise(StandardError,"Could not find mock on your system, exiting") unless File.executable?(mock)

      mock_configs = Pkg.get_mock_configs
      unless chroot
        raise(StandardError,
          "Error: No mock chroot provided. Your choices are:\n  #{mock_configs.join("\n  ")}"
        )
      end

      # If you pass a config file, just take it
      unless chroot.split('.').last == 'cfg'
        unless mock_configs.include?(chroot)
          raise(StandardError,
            "Error: Invalid mock chroot provided. Your choices are:\n  #{mock_configs.join("\n  ")}"
          )
        end
      end

      raise %Q(unique_ext must be a String ("#{unique_ext}" = #{unique_ext.class})) unless unique_ext.is_a?(String)

      # if true, restrict yum to the chroot's local yum cache (defaults to false)
      mock_offline = ENV.fetch( 'SIMP_RAKE_MOCK_OFFLINE', 'N' ).chomp.index( %r{^(1|Y|true|yes)$} ) || false

      mock_cmd =  "#{mock} --quiet"
      mock_cmd += " --uniqueext=#{unique_ext}" if unique
      mock_cmd += ' --offline'                 if mock_offline

      initialized = is_mock_initialized(mock_cmd, chroot)

      unless initialized && init
        sh %Q(#{mock_cmd} --root #{chroot} --init #{unique_ext})
      else
        # Remove any old build cruft from the mock directory.
        # This is kludgy but WAY faster than rebuilding them all, even with a cache.
        sh %Q(#{mock_cmd} --root #{chroot} --chroot "/bin/rm -rf /builddir/build/BUILDROOT /builddir/build/*/*")
      end

      # Install useful stock packages
      if ENV.fetch( 'SIMP_RAKE_MOCK_EXTRAS', 'yes' ) == 'yes'
        pkgs = ['openssl', 'openssl-devel']

        env_pkgs = ENV.fetch('SIMP_RAKE_MOCK_PKGS','')
        unless env_pkgs.empty?
          pkgs = pkgs + env_pkgs.split(',')
        end

        pkgs.each do |pkg|
          sh %Q(#{mock_cmd} --root #{chroot} --install #{pkg})
        end
      end

      return mock_cmd + " --no-clean --no-cleanup-after --resultdir=#{@pkg_dir} --disable-plugin=package_state"
    end

    def is_mock_initialized( mock_cmd, chroot )
      @@initialized_mocks ||= []
      return true if @@initialized_mocks.include?(chroot)

      %x{#{mock_cmd} --root #{chroot} --chroot "test -d /tmp" &> /dev/null }
      initialized = $?.success?
      @@initialized_mocks << chroot

      # A simple test to see if the chroot is initialized.
      initialized
    end
  end
end
