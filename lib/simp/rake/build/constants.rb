require 'rake/tasklib'

module Simp::Rake; end
module Simp::Rake::Build; end
module Simp::Rake::Build::Constants
  def os_build_metadata(distro=nil, version=nil, arch=nil)
    unless @member_vars_initialized
      init_member_vars(Dir.pwd)
    end

    metadata = nil

    build_metadata_file = File.join(@distro_build_dir, 'build_metadata.yaml')

    if File.exist?(build_metadata_file)
      build_metadata = YAML.load_file(build_metadata_file)

      if distro
        begin
          metadata_init = { 'distributions' => {} }
          metadata = metadata_init.dup

          if build_metadata['distributions'][distro]
            if version && build_metadata['distributions'][distro][version]
              metadata['distributions'][distro] = {}
              metadata['distributions'][distro][version] = build_metadata['distributions'][distro][version].dup

              if arch && build_metadata['distributions'][distro][version]['arch'].include?(arch)
                metadata['distributions'][distro][version]['arch'] = Array(arch)
              else
                raise(NoMethodError)
              end
            else
              metadata['distributions'][distro] = build_metadata['distributions'][distro].dup
            end

            # Build everything that we've selected
            metadata['distributions'][distro].keys.each do |d|
              metadata['distributions'][distro][d]['build'] = true
            end
          end

          if metadata['distributions'].empty?
            raise(NoMethodError)
          end
        rescue NoMethodError
          $stderr.puts(%(Error: Could not find distribution for '#{ENV['SIMP_BUILD_distro']}'))
          $stderr.puts(%(  Check #{File.expand_path(build_metadata_file)}))
          exit(1)
        end
      else
        metadata = build_metadata
      end
    end

    return metadata
  end

  def init_member_vars( base_dir )
    return if @member_vars_initialized

    @run_dir           = Dir.pwd
    @base_dir          = base_dir
    @build_arch        = ENV['SIMP_BUILD_arch'] || %x{#{:facter} hardwaremodel 2>/dev/null}.chomp
    @build_dir         = File.join(@base_dir, 'build')
    @dvd_dir           = File.join(@build_dir, 'DVD_Overlay')
    @target_dists      = ['CentOS', 'RedHat']
    @dist_dir          = File.join(@build_dir, 'dist')
    @src_dir           = File.join(@base_dir, 'src')
    @dvd_src           = File.join(@src_dir, 'DVD')
    @spec_dir          = File.join(@src_dir, 'build')
    @spec_file         = FileList[File.join(@spec_dir, '*.spec')]
    @simp_version      = Simp::RPM.get_info(File.join(@spec_dir, 'simp.spec'))[:full_version]
    @simp_dvd_dirs     = ["SIMP","ks","Config"]
    @distro_build_dir  = File.join(@build_dir,'distributions')
    @os_build_metadata = nil
    @member_vars_initialized = true

    if ENV['SIMP_BUILD_distro']
      distro, version, arch = ENV['SIMP_BUILD_distro'].split(/,|\//)

      @os_build_metadata = os_build_metadata(distro, version, arch)
    else
      @os_build_metadata = os_build_metadata()
    end

    if @os_build_metadata && !@os_build_metadata.empty?
      $simp6 = true
      $simp6_clean_dirs = []

      @os_build_metadata['distributions'].keys.sort.each do |d|
        @os_build_metadata['distributions'][d].keys.sort.each do |v|
          next unless @os_build_metadata['distributions'][d][v]['build']
          @os_build_metadata['distributions'][d][v]['arch'].sort.each do |a|
            $simp6_clean_dirs << File.join(@distro_build_dir, d, v, a, 'SIMP')
            $simp6_clean_dirs << File.join(@distro_build_dir, d, v, a, 'SIMP_ISO*')
          end
        end
      end
    end
  end
end
