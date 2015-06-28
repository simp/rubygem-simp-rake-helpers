# This file provided many common build-related tasks and helper methods from
# the SIMP Rakefile ecosystem.

require 'rake'
require 'rake/clean'
require 'rake/tasklib'
require 'fileutils'
require 'find'
require 'simp/rpm'

module Simp; end
module Simp::Rake
  class Pkg < ::Rake::TaskLib

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

    #
    attr_accessor :unique_name

    # array of items to ignore when checking if the tarball needs to be rebuilt
    attr_accessor :ignore_changes_list

    def initialize( base_dir, unique_name=nil )
       @base_dir            = base_dir
       @pkg_name            = File.basename(@base_dir)
       @spec_file           = Dir.glob("#{@base_dir}/build/*.spec").first
       @pkg_dir             = "#{@base_dir}/dist"
       @exclude_list        = [ File.basename(@pkg_dir) ]
       @clean_list          = []
       @ignore_changes_list = []
       @chroot_name         = unique_name

       ::CLEAN.include( @pkg_dir )

       yield self if block_given?

       ::CLEAN.include( @clean_list )

       @spec_info      = Pkg.get_info( @spec_file )
       @chroot_name    = @chroot_name || "#{@spec_info[:name]}__#{ENV.fetch( 'USER', 'USER' )}"
       @dir_name       = "#{@spec_info[:name]}-#{@spec_info[:version]}"
       @mfull_pkg_name = "#{@dir_name}-#{@spec_info[:release]}"
       @full_pkg_name  = @mfull_pkg_name.gsub("%{?snapshot_release}","")
       @tar_dest = "#{@pkg_dir}/#{@full_pkg_name}.tar.gz"

       define
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
      task :default => 'pkg:tar'
      self
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

        # :pkg:tar
        # -----------------------------
        desc <<-EOM
        Build the #{@pkg_name} tar package
            * :snapshot_release - Add snapshot_release (date and time) to rpm
                                  version, rpm spec file must have macro for
                                  this to work.
        EOM
        task :tar,[:snapshot_release] => [@pkg_dir] do |t,args|
          args.with_defaults(:snapshot_release => false)

          l_date = ''
          if args.snapshot_release == 'true'
            l_date = '.' + "#{TIMESTAMP}"
            @tar_dest = "#{@pkg_dir}/#{@full_pkg_name}#{l_date}.tar.gz"
          end

          target_dir = File.basename(@base_dir)

          Dir.chdir(%(#{@base_dir}/..)) do
            Find.find(target_dir) do |path|
              Find.prune if path =~ /^\.git/
              Find.prune if path == "#{@pkg_name}/#{File.basename(@pkg_dir)}"
              Find.prune if @ignore_changes_list.include?(path)
              next if File.directory?(path)
              unless uptodate?(@tar_dest,[path])
                sh %Q(tar --owner 0 --group 0 --exclude-vcs --exclude=#{@exclude_list.join(' --exclude=')} --transform='s/^#{@pkg_name}/#{@dir_name}/' -cpzf "#{@tar_dest}" #{@pkg_name})
                break
              end
            end
          end
        end
      end
    end

    def define_pkg_srpm
      namespace :pkg do
        desc <<-EOM
        Build the #{@pkg_name} SRPM
          Building RPMs requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
            * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1)."
            * :unique - Whether or not to build the SRPM in a unique Mock environment.
                        This can be very useful for parallel builds of all modules.
            * :snapshot_release - Add snapshot_release (date and time) to rpm version.
                        Rpm spec file must have macro for this to work.
        EOM
        task :srpm,[:chroot,:unique,:snapshot_release] => [:tar] do |t,args|
          args.with_defaults(:unique => false)
          args.with_defaults(:snapshot_release => false)

          l_date = ''
          if args.snapshot_release == 'true'
            l_date = '.' + "#{TIMESTAMP}"
            mocksnap = "-D 'snapshot_release #{l_date}'"
            @tar_dest = "#{@pkg_dir}/#{@full_pkg_name}#{l_date}.tar.gz"
          end

          mock_cmd = mock_pre_check( args.chroot, @chroot_name, args.unique )

          srpms = Dir.glob(%(#{@pkg_dir}/#{@full_pkg_name}#{l_date}.*src.rpm))

          if require_rebuild?(@tar_dest,srpms)
            cmd = %Q(#{mock_cmd} --no-clean --root #{args.chroot} #{mocksnap} --buildsrpm --spec #{@spec_file} --source #{@pkg_dir})
            sh cmd
          end
        end
      end
    end

    def define_pkg_rpm
      namespace :pkg do
        desc <<-EOM
        Build the #{@pkg_name} RPM
          Building RPMs requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
            * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1)."
            * :unique - Whether or not to build the RPM in a unique Mock environment.
                        This can be very useful for parallel builds of all modules.
            * :snapshot_release - Add snapshot_release (date and time) to rpm version.
                        Rpm spec file must have macro for this to work.
        EOM
        task :rpm,[:chroot,:unique,:snapshot_release] do |t,args|
          args.with_defaults(:unique => false)
          args.with_defaults(:snapshot_release => false)

          l_date = ''
          if args.snapshot_release == 'true'
            l_date = '.' + "#{TIMESTAMP}"
            mocksnap = "-D 'snapshot_release #{l_date}'"
            @tar_dest = "#{@pkg_dir}/#{@full_pkg_name}#{l_date}.tar.gz"
          end

          Rake::Task['pkg:srpm'].invoke(args.chroot,args.unique,args.snapshot_release)

          mock_cmd = mock_pre_check(args.chroot, @chroot_name, args.unique)

          rpms = Dir.glob(%(#{@pkg_dir}/#{@full_pkg_name}#{l_date}*.rpm))
          srpms = rpms.select{|x| x =~ /src\.rpm$/}
          rpms = (rpms - srpms)

          srpms.each do |srpm|
            if require_rebuild?(srpm,rpms)
              cmd = %Q(#{mock_cmd} --root #{args.chroot} #{mocksnap} #{srpm})
              sh cmd
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
        Scrub the #{@pkg_name} mock build directory
        EOM
        task :scrub,[:chroot,:unique] do |t,args|
          args.with_defaults(:unique => false)

          mock_cmd = mock_pre_check( args.chroot, @chroot_name, args.unique, false )
          cmd = %Q(#{mock_cmd} --scrub=all)
          sh cmd
        end

      end

    end

    # ------------------------------------------------------------------------------
    # helper methods
    # ------------------------------------------------------------------------------
    # Pull the main RPM information out of the package spec file.
    def Pkg.get_info(specfile)
      return Simp::RPM.get_info(specfile)
    end

    # Get a list of all of the mock configs available on the system.
    def Pkg.get_mock_configs
      Dir.glob('/etc/mock/*.cfg').sort.map{ |x| x = File.basename(x,'.cfg')}
    end

    # Return True if any of the 'output_files' are older than the 'src_file'
    def require_rebuild?(src_file,output_files)
      require_rebuild = false
      require_rebuild = true if output_files.empty?
      unless require_rebuild
        output_files.each do |outfile|
          unless uptodate?(outfile,Array(src_file))
            require_rebuild = true
            break
          end
        end
      end

      require_rebuild
    end

    # Run some pre-checks to make sure that mock will work properly.
    #
    # chroot   = name of mock chroot to use
    # unique_ext = TODO
    # Pass init=false if you do not want the function to initialize.
    #
    # Returns a String that contains the appropriate mock command.
    def mock_pre_check( chroot, unique_ext, unique=false, init=true )

      raise %Q(unique_ext must be a String ("#{unique_ext}" = #{unique_ext.class})) unless unique_ext.is_a? String

      mock = ENV['mock'] || '/usr/bin/mock'
      raise(Exception,"Could not find mock on your system, exiting") unless File.executable?('/usr/bin/mock')

      mock_configs = Pkg.get_mock_configs
      unless chroot
        raise(Exception,
          "Error: No mock chroot provided. Your choices are:\n  #{mock_configs.join("\n  ")}"
        )
      end
      unless mock_configs.include?(chroot)
        raise(Exception,
          "Error: Invalid mock chroot provided. Your choices are:\n  #{mock_configs.join("\n  ")}"
        )
      end

      # if true, restrict yum to the chroot's local yum cache (defaults to false)
      mock_offline = ENV.fetch( 'SIMP_RAKE_MOCK_OFFLINE', 'N' ).chomp.index( %r{^(1|Y|true|yes)$} ) || false

      mock_cmd =  "#{mock} --quiet"
      mock_cmd += " --uniqueext=#{unique_ext}" if unique
      mock_cmd += ' --offline'                 if mock_offline

      initialized = is_mock_initialized( mock_cmd, chroot)

      unless initialized && init
        sh %Q(#{mock_cmd} --root #{chroot} --init ##{unique_ext} )
      else
        # Remove any old build cruft from the mock directory.
        # This is kludgy but WAY faster than rebuilding them all, even with a cache.
        sh %Q(#{mock_cmd} --root #{chroot} --chroot "/bin/rm -rf /builddir/build/BUILDROOT /builddir/build/*/*")
      end

      mock_cmd + " --no-clean --no-cleanup-after --resultdir=#{@pkg_dir} --disable-plugin=package_state"
    end

    def is_mock_initialized( mock_cmd, chroot )
      %x{#{mock_cmd} --root #{chroot} --chroot "test -d /tmp" &> /dev/null }
      initialized = $?.success?

      # A simple test to see if the chroot is initialized.
      initialized
    end

    def pry
      #FIXME: remove this debugging nonsense before release
      if Rake::verbose.is_a? TrueClass
        require 'pry'
        binding.pry
      end
    end
  end
end
