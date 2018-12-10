require 'simp/rpm/packageinfo'

module Simp; end
module Simp::Rpm; end

class Simp::Rpm::Utils

  def self.create_rpm_build_metadata(project_dir, srpms=nil, rpms=nil, verbose = false)
    require 'yaml'

    last_build = {
      'git_hash' => %x(git rev-list --max-count=1 HEAD).chomp,
      'srpms'    => {},
      'rpms'     => {}
    }


    Dir.chdir(File.join(project_dir, 'dist')) do
      if srpms.nil? or rpms.nil?
        all_rpms = Dir.glob('*.rpm')
        srpms = Dir.glob('src.rpm')
        rpms = all_rpms - srpms
      end

      srpms.each do |srpm|
        file_stat = File.stat(srpm)

        last_build['srpms'][File.basename(srpm)] = {
          'metadata'  => Simp::Rpm::PackageInfo.new(srpm, verbose).info,
          'size'      => file_stat.size,
          'timestamp' => file_stat.ctime,
          'path'      => File.absolute_path(srpm)
        }
      end

      rpms.each do |rpm|
        file_stat = File.stat(rpm)

        last_build['rpms'][File.basename(rpm)] = {
          'metadata'  => Simp::Rpm::PackageInfo.new(rpm, verbose).info,
          'size'      => file_stat.size,
          'timestamp' => file_stat.ctime,
          'path'     => File.absolute_path(rpm)
         }
      end

      FileUtils.mkdir_p(File.join(project_dir, 'dist', 'logs'))
      File.open('logs/last_rpm_build_metadata.yaml','w') do |fh|
        fh.puts(last_build.to_yaml)
      end
    end
  end

  # @returns the architecture of an RPM
  #
  # +rpm+:: RPM path
  # +arch_list+:: Set of typical architectures for this sytem.  Used to
  #               speed up the determination of the RPM architecture
  #
  def self.get_rpm_arch(rpm, arch_list = ['noarch', 'x86_64'])
    # first try fast and dirty way, which will work for RPMs following Fedoras
    # naming conventions (e.g., CentOS, RedHat and SIMP RPMs)
    rpm_arch = rpm.split('.')[-2]
    unless arch_list.include?(rpm_arch)
      # extract from the RPM metadata
      rpm_arch = Simp::Rpm::PackageInfo.new(rpm).arch
    end
    rpm_arch
  end

end
