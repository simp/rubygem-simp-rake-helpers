require 'rake/tasklib'

module Simp::Rake; end
module Simp::Rake::Build; end
module Simp::Rake::Build::Constants
  def init_member_vars( base_dir )
    return if @member_vars_initialized

    require 'facter'

    $simp6 = true
    $simp6_clean_dirs = []

    @build_distro = Facter.fact('operatingsystem').value
    @build_version = Facter.fact('operatingsystemmajrelease').value
    @build_arch = Facter.fact('architecture').value

    @run_dir           = Dir.pwd
    @base_dir          = base_dir
    @build_dir         = File.join(@base_dir, 'build')
    @target_dists      = ['CentOS', 'RedHat']
    @src_dir           = File.join(@base_dir, 'src')
    @spec_dir          = File.join(@src_dir, 'build')
    @spec_file         = FileList[File.join(@spec_dir, '*.spec')]
    @simp_version      = Simp::RPM.get_info(File.join(@src_dir, 'assets', 'simp', 'build', 'simp.spec'))[:full_version]
    @simp_dvd_dirs     = ["SIMP","ks","Config"]
    @member_vars_initialized = true

    @distro_build_dir = File.join(@build_dir, 'distributions', @build_distro, @build_version, @build_arch)
    @dvd_src           = File.join(@distro_build_dir, 'DVD')
    @dvd_dir           = File.join(@distro_build_dir, 'DVD_Overlay')

    if File.exist?(File.join(@build_dir, 'distributions'))
      @build_dir = @distro_build_dir
    end

    @dist_dir = File.join(@build_dir, 'dist')
    @rpm_dir  = "#{@build_dir}/SIMP/RPMS"
  end
end
