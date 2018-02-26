require 'spec_helper_acceptance'
require_relative 'support/pkg_rpm_helpers'

require 'beaker/puppet_install_helper'
require 'json'

RSpec.configure do |c|
  c.include Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
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
              '/opt/puppetlabs/bin/puppet config --section master set codedir /opt/mock_simp_rpm_helper/code; ' +
              '/opt/puppetlabs/bin/puppet config --section master set confdir /opt/mock_simp_rpm_helper/code'


    comment 'build and install prereq packages'
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

      let(:testpackages) do
        [
          'oldpackage-1.0',
          'oldpackage-2.0',
          'newpackage-2.0',
          'newpackage-3.0',
        ]
      end

      context 'with four RPMs in a SIMP-3895 configuration' do

        it 'should create RPMs' do
          testpackages.each do |package|
            on host, %Q(#{run_cmd} "cd #{pkg_root_dir}/#{package}; ) +
                      %Q(rvm use default; bundle update --local || bundle update")
            rpm_name = "pupmod-simp-#{package.split(/-\d/).first}"
            # In case previous tests haven't been clean
            on host, "rpm -q #{rpm_name} && rpm -e #{rpm_name}; :"

            on host, %(#{run_cmd} "cd #{pkg_root_dir}/#{package}; #{rake_cmd} pkg:rpm")
          end
        end


        it 'should install oldpackage-1.0' do
          on host, "cd #{pkg_root_dir}/oldpackage-1.0; rpm -Uvh dist/pupmod-simp-oldpackage*.noarch.rpm"
        end


        it "should transfer oldpackage 1.0's files to the code directory" do
          result = on host, 'cat /opt/mock_simp_rpm_helper/code/oldpackage/metadata.json'
          metadata = JSON.parse(result.stdout)
          expect(metadata['name']).to eq 'simp-oldpackage'
          expect(metadata['version']).to eq '1.0.0'
        end


        it 'should upgrade to oldpackage-2.0' do
          on host, "yum install -y #{pkg_root_dir}/oldpackage-2.0/dist/pupmod-simp-oldpackage-2.0.0-0.noarch.rpm"
        end


        it "should transfer oldpackage 2.0's files to the code directory" do
          result = on host, 'cat /opt/mock_simp_rpm_helper/code/oldpackage/metadata.json'
          metadata = JSON.parse(result.stdout)
          expect(metadata['name']).to eq 'simp-oldpackage'
          expect(metadata['version']).to eq '2.0.0'
        end


        it 'should upgrade to newpackage-2.0' do
          on host, "yum install -y #{pkg_root_dir}/newpackage-2.0/dist/pupmod-simp-newpackage-2.0.0-0.noarch.rpm"
        end


        it "should transfer newpackage 2.0's files to the code directory" do
          result = on host, 'cat /opt/mock_simp_rpm_helper/code/newpackage/metadata.json'
          metadata = JSON.parse(result.stdout)
          expect(metadata['name']).to eq 'simp-newpackage'
          expect(metadata['version']).to eq '2.0.0'
        end

      end
    end
  end
end
