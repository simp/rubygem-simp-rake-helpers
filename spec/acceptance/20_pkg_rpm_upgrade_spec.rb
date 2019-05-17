require 'spec_helper_acceptance'
require_relative 'support/pkg_rpm_helpers'

require 'beaker/puppet_install_helper'
require 'json'

RSpec.configure do |c|
  c.include Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
end

# This tests RPM upgrade scenarios for components that use
# simp-adapter's simp_rpm_helper to copy files from the RPM install
# directory to a second destination directory


shared_examples_for 'RPM generator' do
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
end

shared_examples_for 'an upgrade path that works safely with simp_rpm_helper' do |first_package_file, second_package_file|
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

      # This verifies all files/dirs from the first package are copied
      on host, "diff -r /usr/share/simp/modules/#{first_package_module_name} /opt/test/puppet/code/#{first_package_module_name}"
    end

    it "should upgrade to #{second_package_file}" do
      on host, "cd #{pkg_root_dir}/#{second_package_dir_name.gsub(/\.\d+$/,'')}; rpm -Uvh dist/#{second_package_file}"
    end

    it "should transfer contents of #{second_package_file} into the code directory" do
      result = on host, "cat /opt/test/puppet/code/#{second_package_module_name}/metadata.json"
      metadata = JSON.parse(result.stdout)
      expect(metadata['name']).to eq second_package_forge_name
      expect(metadata['version']).to eq second_package_version

      # This verifies all files/dirs from the second package are copied and
      # no files/dirs onyn in the old package remain
      on host, "diff -r /usr/share/simp/modules/#{second_package_module_name} /opt/test/puppet/code/#{second_package_module_name}"
    end

  end
end

describe 'rake pkg:rpm + component upgrade scenarios' do

  before :all do
    copy_host_files_into_build_user_homedir(hosts)

    comment 'ensure the Puppet AIO is installed'
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

      # This tests standard upgrades, which should 
      context 'with normal module RPM upgrades' do
        let(:pkg_root_dir) do
          '/home/build_user/host_files/spec/acceptance/files/package_upgrades'
        end

        let(:testpackages) do
          [
            'pupmod-simp-testpackage-1.0',
            'pupmod-simp-testpackage-2.0',
          ]
        end

        context 'RPM build' do
          it_should_behave_like('RPM generator')
        end

        context 'RPM upgrades' do
          it_should_behave_like('an upgrade path that works safely with simp_rpm_helper',
                                'pupmod-simp-testpackage-1.0.0-0.noarch.rpm',
                                'pupmod-simp-testpackage-2.0.0-0.noarch.rpm')
        end

        context 'RPM erase' do
          it 'should remove copied files on an erase' do
            on host, 'rpm -e pupmod-simp-testpackage'
            on host, 'ls /opt/test/puppet/code/testpackage', acceptable_exit_codes: [2]
          end
        end
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
      #
      context 'with module RPMs that are susceptible to SIMP-3895' do
        let(:pkg_root_dir) do
          '/home/build_user/host_files/spec/acceptance/files/custom_scriptlet_triggers'
        end

        let(:testpackages) do
          [
            'pupmod-old-package-1.0',
            'pupmod-old-package-2.0',
            'pupmod-old-package-2.2',
            'pupmod-new-package-2.1',
            'pupmod-new-package-3.0',
          ]
        end

        context 'RPM build' do
          it_should_behave_like('RPM generator')
        end

        context 'RPM upgrades' do
          it_should_behave_like('an upgrade path that works safely with simp_rpm_helper',
                                'pupmod-old-package-1.0.0-0.noarch.rpm',
                                'pupmod-old-package-2.0.0-0.noarch.rpm')

          it_should_behave_like('an upgrade path that works safely with simp_rpm_helper',
                                'pupmod-old-package-1.0.0-0.noarch.rpm',
                                'pupmod-new-package-2.1.0-0.noarch.rpm')

          it_should_behave_like('an upgrade path that works safely with simp_rpm_helper',
                                'pupmod-new-package-2.1.0-0.noarch.rpm',
                                'pupmod-old-package-2.2.0-0.noarch.rpm')

          it_should_behave_like('an upgrade path that works safely with simp_rpm_helper',
                                'pupmod-old-package-1.0.0-0.noarch.rpm',
                                'pupmod-new-package-3.0.0-0.noarch.rpm')

          it_should_behave_like('an upgrade path that works safely with simp_rpm_helper',
                                'pupmod-old-package-2.0.0-0.noarch.rpm',
                                'pupmod-new-package-2.1.0-0.noarch.rpm')

          it_should_behave_like('an upgrade path that works safely with simp_rpm_helper',
                                'pupmod-old-package-2.0.0-0.noarch.rpm',
                                'pupmod-new-package-3.0.0-0.noarch.rpm')

          it_should_behave_like('an upgrade path that works safely with simp_rpm_helper',
                                'pupmod-old-package-2.2.0-0.noarch.rpm',
                                'pupmod-new-package-3.0.0-0.noarch.rpm')

          it_should_behave_like('an upgrade path that works safely with simp_rpm_helper',
                                'pupmod-new-package-2.1.0-0.noarch.rpm',
                                'pupmod-new-package-3.0.0-0.noarch.rpm')
        end
      end
    end
  end
end
