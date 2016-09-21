require 'rake/tasklib'

module Simp::Rake; end
module Simp::Rake::Build; end
module Simp::Rake::Build::Constants
  def init_member_vars( base_dir )
    @run_dir   = Dir.pwd
    @base_dir  = base_dir
    @build_arch = ENV['buld_arch'] || %x{#{:facter} hardwaremodel 2>/dev/null}.chomp
    @build_dir  = "#{@base_dir}/build"
    @dist_dir   = "#{@build_dir}/dist"
    @dvd_dir    = "#{@build_dir}/DVD_Overlay"
    @src_dir    = "#{@base_dir}/src"
    @dvd_src       = "#{@src_dir}/DVD"
    @spec_dir      = "#{@src_dir}/build"
    @spec_file    = FileList["#{@spec_dir}/*.spec"]
    @target_dists  = ['CentOS','RHEL']  # The first item is the default build...
    @simp_version  = Simp::Utils::RPM.get_info("#{@spec_dir}/simp.spec")[:full_version]
    @rhel_version  = ENV['rhel_version'] || '6'
    @simp_dvd_dirs = ["SIMP","ks","Config"]
  end
end

