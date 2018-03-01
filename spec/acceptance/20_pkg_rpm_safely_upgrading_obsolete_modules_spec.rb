require 'spec_helper_acceptance'
require_relative 'support/pkg_rpm_helpers'

require 'beaker/puppet_install_helper'
require 'json'

RSpec.configure do |c|
  c.include Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
end


# These tests demonstrate custom RPM triggers that work around the obsolete
# module RPM upgrate + simp_rpm_helper problem described in SIMP-3895:
#
#    https://simp-project.atlassian.net/browse/SIMP-3988
#
# The expected outcome is that simp_rpm_helper always ensures the correct
# content is installed after an upgrade, even during after a package has been
# obsoleted.  This is accomplished via %triggerpostun -- <name of old package>
#
# old 1.0 -> old 2.0 = no need for a trigger
# old 1.0 -> new 2.0 = must re-run simp_rpm_helper
# old 1.0 -> new 3.0 = must re-run simp_rpm_helper
# old 2.0 -> new 2.0 = must re-run simp_rpm_helper
# old 2.0 -> new 3.0 = must re-run simp_rpm_helper
# new 2.0 -> new 3.0 = no need for a trigger


shared_examples_for 'an upgrade path that works safely with rpm_simp_helper' do |first_package_file, second_package_file|
  let( :rpm_regex ) do
    /^(?<name>pupmod-[a-z0-9_]+-[a-z0-9_]+)-(?<version>\d+\.\d+\.\d+)-(?<release>\d+)\..*\.rpm$/
  end

  let( :first_package_version ){ first_package_file.match(rpm_regex)['version'] }
  let( :first_package_name ){ first_package_file.match(rpm_regex)['name'] }
  let( :first_package_forge_name ){ first_package_name.sub(/^[^-]+-/,'') }
  let( :first_package_module_name ){ first_package_forge_name.sub(/^[^-]+-/,'') }
  let( :first_package_dir_name ){ first_package_name + '-' + first_package_version.sub(/\.\d+-\d+$/,'') }

  let( :second_package_name ){ second_package_file.match(rpm_regex)['name'] }
  let( :second_package_forge_name ){ second_package_name.sub(/^[^-]+-/,'') }
  let( :second_package_module_name ){ second_package_forge_name.sub(/^[^-]+-/,'') }
  let( :second_package_version ){ second_package_file.match(rpm_regex)['version'] }
  let( :second_package_dir_name ){ second_package_name + '-' + second_package_version.sub(/\.\d+-\d+$/,'') }

  context "When upgrading from #{first_package_file} to #{second_package_file}" do
    it "should clean out any old installs" do
      on host, "rpm -e #{first_package_name} &> /dev/null; " +
               "rpm -e #{second_package_name} &> /dev/null ",
               accept_all_exit_codes: true
    end

    it "should install #{first_package_file}" do
      on host, "cd #{pkg_root_dir}/#{first_package_dir_name.gsub(/\.\d+$/,'')}; "+
               "rpm -Uvh dist/#{first_package_file}"
    end

    it "should transfer contents of #{first_package_file} into the code directory" do
      result = on host, "cat /opt/test/puppet/code/#{first_package_module_name}/metadata.json"
      metadata = JSON.parse(result.stdout)
      expect(metadata['name']).to eq first_package_forge_name
      expect(metadata['version']).to eq first_package_version
    end

    it "should upgrade to #{second_package_file}" do
      on host, "cd #{pkg_root_dir}/#{second_package_dir_name.gsub(/\.\d+$/,'')}; rpm -Uvh dist/#{second_package_file}"
    end

    it "should transfer contents of #{second_package_file} into the code directory" do
      result = on host, "cat /opt/test/puppet/code/#{second_package_module_name}/metadata.json"
      metadata = JSON.parse(result.stdout)
      expect(metadata['name']).to eq second_package_forge_name
      expect(metadata['version']).to eq second_package_version
    end


  end
end

describe 'rake pkg:rpm + modules with customized content to safely upgrade obsoleted packagess' do

  let(:pkg_root_dir) do
    '/home/build_user/host_files/spec/acceptance/files/custom_scriptlet_triggers'
  end

  before :all do
    copy_host_files_into_build_user_homedir(hosts)

    comment 'ensure the Puppet AIO is installed'
    ENV['PUPPET_INSTALL_TYPE'] ||= 'agent'
    ENV['PUPPET_INSTALL_VERSION'] ||= '1.10.6'
    run_puppet_install_helper_on(hosts)

    comment 'configure puppet agent to look like a Puppet server for simp_rpm_helper'
    on hosts, '/opt/puppetlabs/bin/puppet config --section master set user root; ' +
              '/opt/puppetlabs/bin/puppet config --section master set group root; ' +
              '/opt/puppetlabs/bin/puppet config --section master set codedir /opt/test/puppet/code; ' +
              '/opt/puppetlabs/bin/puppet config --section master set confdir /opt/test/puppet/code'


    comment 'build and install mock RPMs'
    mock_pkg_dir = '/home/build_user/host_files/spec/acceptance/files/mock_packages'
    on hosts, %Q[#{run_cmd} "cd #{mock_pkg_dir}; rm -rf pkg"]
    on hosts, %Q[#{run_cmd} "cd #{mock_pkg_dir}; bash rpmbuild.sh simp-adapter.spec"]
    on hosts, %Q[#{run_cmd} "cd #{mock_pkg_dir}; bash rpmbuild.sh pupmod-puppetlabs-stdlib.spec"]
    on hosts, %Q[#{run_cmd} "cd #{mock_pkg_dir}; bash rpmbuild.sh pupmod-simp-simplib.spec"]
    on hosts, %Q[#{run_cmd} "cd #{mock_pkg_dir}; bash rpmbuild.sh pupmod-simp-foo.spec"]

    on hosts, %Q[rpm -Uvh "#{mock_pkg_dir}/pkg/dist/*.noarch.rpm"], acceptable_exit_codes: [0,1]
  end

  hosts.each do |_host|
    context "on #{_host}" do
      let!(:host){ _host }

      context 'with module RPMs that are suceptible to SIMP-3895' do

        let(:testpackages) do
          [
            'pupmod-old-package-1.0',
            'pupmod-old-package-2.0',
            'pupmod-old-package-2.2',
            'pupmod-new-package-2.1',
            'pupmod-new-package-3.0',
          ]
        end

        it 'should create RPMs' do
          testpackages.each do |package|
            on host, %Q(#{run_cmd} "cd #{pkg_root_dir}/#{package}; ) +
                      %Q(rvm use default; bundle update --local || bundle update")
            rpm_name = package.sub(/-[^-]+$/,'')
            # In case previous tests haven't been clean
            on host, "rpm -q #{rpm_name} && rpm -e #{rpm_name}; :"

            on host, %(#{run_cmd} "cd #{pkg_root_dir}/#{package}; #{rake_cmd} pkg:rpm")
          end
        end

        it_should_behave_like('an upgrade path that works safely with rpm_simp_helper',
                              'pupmod-old-package-1.0.0-0.noarch.rpm',
                              'pupmod-old-package-2.0.0-0.noarch.rpm')

        it_should_behave_like('an upgrade path that works safely with rpm_simp_helper',
                              'pupmod-old-package-1.0.0-0.noarch.rpm',
                              'pupmod-new-package-2.1.0-0.noarch.rpm')

        it_should_behave_like('an upgrade path that works safely with rpm_simp_helper',
                              'pupmod-new-package-2.1.0-0.noarch.rpm',
                              'pupmod-old-package-2.2.0-0.noarch.rpm')

        it_should_behave_like('an upgrade path that works safely with rpm_simp_helper',
                              'pupmod-old-package-1.0.0-0.noarch.rpm',
                              'pupmod-new-package-3.0.0-0.noarch.rpm')

        it_should_behave_like('an upgrade path that works safely with rpm_simp_helper',
                              'pupmod-old-package-2.0.0-0.noarch.rpm',
                              'pupmod-new-package-2.1.0-0.noarch.rpm')

        it_should_behave_like('an upgrade path that works safely with rpm_simp_helper',
                              'pupmod-old-package-2.0.0-0.noarch.rpm',
                              'pupmod-new-package-3.0.0-0.noarch.rpm')

        it_should_behave_like('an upgrade path that works safely with rpm_simp_helper',
                              'pupmod-old-package-2.2.0-0.noarch.rpm',
                              'pupmod-new-package-3.0.0-0.noarch.rpm')

        it_should_behave_like('an upgrade path that works safely with rpm_simp_helper',
                              'pupmod-new-package-2.1.0-0.noarch.rpm',
                              'pupmod-new-package-3.0.0-0.noarch.rpm')
      end
    end
  end
end
