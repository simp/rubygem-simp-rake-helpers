require 'rake/tasklib'
require 'simp/rpm/specfileinfo'

module Simp::Rake; end
module Simp::Rake::Build; end
module Simp::Rake::Build::Constants
  def init_member_vars( base_dir )
    return if @member_vars_initialized

    require 'facter'

    $simp6 = true
#FIXME the use of $simp6_clean_dir to add to ::CLEAN/::CLOBBER does not work...
    $simp6_clean_dirs = []

    # Global verbosity settings
#FIXME Should use SIMP_PKG_verbose and have yes,no,number >= 0
    @rpm_verbose = ( ENV.fetch('SIMP_RPM_verbose','no') == 'yes')

    cpu_limit_override = ENV.fetch( 'SIMP_RAKE_LIMIT_CPUS', '-1' ).strip.to_i
    @cpu_limit = Simp::Utils::get_cpu_limit(cpu_limit_override)

    # RPM macros specifications. Used to define/undefine macros found in RPM
    # spec files.  Each entry is of the form <name:value> or <!name>, where
    # <name:value> specifies a macro to define and <!name> specifies a macro
    # to undefine.
    @build_rpm_macros = []

    if ENV['SIMP_BUILD_distro']
      distro, version, arch = ENV['SIMP_BUILD_distro'].split(/,|\//)
      # Set up OS-version-related macros used in SIMP asset RPMs
      @build_rpm_macros << "dist:.el#{version}"
      @build_rpm_macros << "rhel:#{version}"
       @build_rpm_macros << "el#{version}:1"
      if version == '6'
        @build_rpm_macros << '!el7'
      else
        @build_rpm_macros << '!el6'
      end
    end

    @build_distro = distro || Facter.fact('operatingsystem').value
    @build_version = version || Facter.fact('operatingsystemmajrelease').value
    @build_arch = arch || Facter.fact('architecture').value

    #NOTE: The macros in SIMP_RPM_macros will take precedence over those
    #      set from SIMP_BUILD_distro, because the rpm command uses the
    #      last define/undefine for any given macro.
    unless ENV['SIMP_RPM_macros'].nil?
      @build_rpm_macros += ENV['SIMP_RPM_macros'].split(',')
    end

    if (ENV.fetch('SIMP_RAKE_PKG_LUA_verbose','no') =='yes')
      @build_rpm_macros << 'lua_debug:1'
    end

    @run_dir      = Dir.pwd
    @base_dir     = base_dir
    @build_dir    = File.join(@base_dir, 'build')
    @target_dists = ['CentOS', 'RedHat']
    @src_dir      = File.join(@base_dir, 'src')

    simp_spec = File.join(@src_dir, 'assets', 'simp', 'build', 'simp.spec')
    @simp_version = Simp::Rpm::SpecFileInfo.new(simp_spec, @build_rpm_macros, @rpm_verbose).full_version

    @distro_build_dir = File.join(@build_dir, 'distributions', @build_distro, @build_version, @build_arch)
    @dvd_src          = File.join(@distro_build_dir, 'DVD')
    @dvd_dir          = File.join(@distro_build_dir, 'DVD_Overlay')

    if File.exist?(File.join(@build_dir, 'distributions'))
      @build_dir = @distro_build_dir
    end

    @member_vars_initialized = true
  end
end
