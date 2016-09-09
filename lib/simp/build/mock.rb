require 'simp/rake/pkg'
require 'simp/utils/sh'

module Simp
  module Simp::Build

    # Interface to the {https://fedoraproject.org/wiki/Mock?rd=Subprojects/Mock Fedora mock} tool for building SIMP packages
    # @note This Class requires the `mock` application to be installed.
    class Simp::Build::Mock
      include Simp::Utils::Sh

      # @!attribute [rw]
      #   Absolute path to `mock` executable
      #   @return [Boolean]
      attr_accessor :mock_bin

      # @!attribute [rw]
      #   Path to mock's config directory
      #   @note   This can be overriden using the environment variable `SIMP_BUILD_mock_config_dir`
      #   @return [String] (default: `/etc/mock`)
      attr_accessor :mock_config_dir

      # @!attribute [rw]
      #   Whether to run mock in 'offline' mode
      #   @note   This can be overriden using the environment variable `SIMP_BUILD_mock_offline`
      #   @return [Boolean] (default: `false`)
      attr_accessor :mock_offline

      # @!attribute [rw]
      #   A unique String, used to keep the mock root exclusive to this instance.
      #   @note   This can be overriden using the environment variable `SIMP_BUILD_mock_uniqueext`
      #   @return [String] (default: '')
      attr_accessor :uniqueext

      # @!attribute [rw]
      #   When true, `mock_init()` will automatically execute if needed during `mock_cmd`
      #   @return [Boolean] (default: `true`)
      attr_accessor :auto_init

      # @!attribute [rw]
      #   Additional mock argmuents
      #   @return [String] (default: `[]`)
      attr_accessor :extra_args

      # @param [String]  chroot
      # @param [String]  uniqueext
      # @param [Boolean] cleanup_after
      def initialize(chroot, result_dir, uniqueext=nil, cleanup_after=false)
        @chroot           = chroot
        @uniqueext        = uniqueext || ENV['SIMP_BUILD_mock_uniqueext'] || ENV['USER']
        @cleanup_after    = cleanup_after
        @auto_init        = true
        @mock_bin         = ENV['SIMP_BUILD_mock_bin']        || '/usr/bin/mock'
        @mock_config_dir  = ENV['SIMP_BUILD_mock_config_dir'] || '/etc/mock'
        @mock_offline     = ENV.fetch('SIMP_BUILD_mock_offline','no') =~ /^yes$/ ? true : false
        @extra_args       = []
        @snapshot_release = ''
        @result_dir       = result_dir # TODO: default to pwd?  require as param?
        @verbose          = :normal
      end


      # Tests for the presence of the mock executable, mock configs, etc.
      #
      # @return [Boolean] `true` if mock environment is good
      # @raise  [RuntimeError] raised with a specific error message if mock won't work.
      def validate_mock_environment
        unless File.executable?(@mock_bin)
          raise(RuntimeError ,"Could not find mock on your system, exiting")
        end

        unless mock_configs.include?(@chroot)
          raise(RuntimeError,
            "Error: Invalid mock chroot provided.  " +
            "Your choices are:\n  #{mock_configs.join("\n  ")}"
          )
        end

        unless File.directory?(@result_dir)
          raise(RuntimeError ,"result_dir must be a directory ('#{@result_dir}')")
        end

        unless @uniqueext.nil? || (@uniqueext.is_a?(String) && !@uniqueext.empty?)
          raise RuntimeError, 'uniqueext must be nil or a non-empty String ' +
                              %Q(("#{@uniqueext}" = #{@uniqueext.class}))
        end

        # TODO: This exhausts the original code's checks.  Should there be more?
        true
      end


      # Constructs the boring part of the mock CLI string
      # @returns [Array] beginning portion of the CLI invocation for mock
      def mock_cmd
        validate_mock_environment

        cmd = ["#{@mock_bin}"]
        cmd = cmd + ["--uniqueext=#{@uniqueext}"] if @uniqueext
        cmd = cmd + ['--offline']                 if @mock_offline
        cmd = cmd + ['--verbose'] if @verbose == :verbose
        cmd = cmd + ['--quiet']   if @verbose == :quiet || @verbose == :silent

        if @auto_init && !initialized?(cmd + ["--root=#{@chroot}"])
          mock_init(cmd + ["--root=#{@chroot}"])
        end

        cmd += ['--no-cleanup-after'] unless @cleanup_after
        cmd += [
                  '--no-clean',
                  "--resultdir=#{@result_dir}",
                  '--disable-plugin=package_state',
                ]
        cmd += @extra_args
        cmd += [
                 "--root=#{@chroot}",
               ]
        cmd
      end


      # A simple test to see if the chroot is initialized.
      # @param [String] _cmd An optional {#mock_cmd} String to use.  If this is not provided, a value will be obtained by running {#mock_cmd}.
      # @returns [Boolean]
      def initialized?(_cmd=nil)
        cmd = _cmd || mock_cmd

        verbose = :quiet
        verbose = @verbose if (@verbose == :silent || @verbose == :verbose)
        status = sh (cmd + ['--chroot', 'test -d /tmp &> /dev/null']), verbose

        status.success?
      end


      # Initialize a mock root
      # @param [String] _cmd An optional {#mock_cmd} String to use.  If this is not provided, a value will be obtained by running {#mock_cmd}.
      def mock_init(_cmd=nil)
        cmd = _cmd || mock_cmd

        unless initialized?(cmd)
          sh cmd + ["--root=#{@chroot}", '--init', "#{@uniqueext}"]
        else
          # Remove any old build cruft from the mock directory.
          # This is kludgy but WAY faster than rebuilding them all, even with a cache.
          # TODO: verify that this is still true
          sh cmd + [
                     "--root=#{@chroot}",
                     '--chroot',
                     "/bin/rm -rf /builddir/build/BUILDROOT /builddir/build/*/*"
                   ]
        end

        # Install useful stock packages
        if ENV.fetch( 'SIMP_BUILD_mock_extras', 'yes' ) == 'yes'
          pkgs     = ['openssl', 'openssl-devel']
          env_pkgs = ENV.fetch('SIMP_RAKE_mock_pkgs','')
          pkgs     = pkgs + env_pkgs.split(',') unless env_pkgs.empty?
          pkgs.each { |pkg| sh (cmd + ['--install', "#{pkg}"]) }
        end
      end


      # Set the verbosity level
      # @param v [Symbol] level
      def verbose=(v)
        unless VERBOSE_LEVELS.include?(v)
          raise ArgumentError, "`verbose=` argument must be one of [#{VERBOSE_LEVELS.join(',')}]"
        end
        @verbose = v
      end

      # Run a shell command inside the mock chroot
      # @parameter [String] arg shell comman arguments(s) to pass to `mock`
      # @returns [Process::Status]
      def run(*arg)
        sh mock_cmd + ['--chroot'] + arg.flatten
      end

      # Purge the chroot tree.
      def clean
        sh mock_cmd + ['--clean']
      end

      # Completely remove the specified chroot or cache dir or all of the chroot and cache.
      def scrub
        sh mock_cmd + ['--scrub=all']
      end

      # Do a yum install PACKAGE inside the chroot. No 'clean' is performed
      # @param [*String]
      def install( *package )
        sh mock_cmd + ['--install'] + package
      end

      def update( *package )
        sh mock_cmd + ['--update'] + package
      end

      def copyin( *src_path, dest_path )
        sh mock_cmd + ['--copyin'] + src_path + [dest_path]
      end

      def copyout( *src_path, dest_path )
        sh mock_cmd + ['--copyout'] + src_path + [dest_path]
      end

      # Builds the specified SRPM either from a spec file and source
      #file/directory or from  SCM.
      def buildsrpm( spec, sources )
        cmd = mock_cmd + ['--buildsrpm', '--spec', spec, '--sources', sources ]
        sh cmd
      end

      # ------------------------------------------------------------------------------
      # helper methods
      # ------------------------------------------------------------------------------

      # Return a list of all of the mock configs available on the system.
      # @return [Array] A list of all the mock configs available on the system.
      def mock_configs
        @mock_configs ||= Dir.glob(File.join(@mock_config_dir,'*.cfg')).sort.map{ |x| x = File.basename(x,'.cfg')}
      end
    end
  end
end
