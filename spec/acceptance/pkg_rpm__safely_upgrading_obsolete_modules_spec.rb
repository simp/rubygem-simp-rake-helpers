require 'spec_helper_acceptance'
require_relative 'support/pkg_rpm_helpers'

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
            on hosts, %Q(#{run_cmd} "cd #{pkg_root_dir}/#{package}; ) +
                      %Q(rvm use default; bundle update --local || bundle update")

            on host, %(#{run_cmd} "cd #{pkg_root_dir}/#{package}; #{rake_cmd} pkg:rpm")
          end

        ##it_should_behave_like 'a module with customized content to safely upgrade obsoleted packages' do

        end
      end

    end
  end
end
