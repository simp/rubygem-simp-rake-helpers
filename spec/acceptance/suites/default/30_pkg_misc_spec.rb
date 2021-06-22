require 'spec_helper_acceptance'
require_relative 'support/pkg_rpm_helpers'

RSpec.configure do |c|
  c.include Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
end


shared_examples_for 'a valid RPM changelog processor' do |project|
  it 'should validate the RPM changelog' do
    on host, %(#{run_cmd} "cd #{pkg_root_dir}/#{project}; #{rake_cmd} pkg:check_rpm_changelog")
  end

  it 'should generate the tag changelog' do
    on host, %(#{run_cmd} "cd #{pkg_root_dir}/#{project}; #{rake_cmd} pkg:create_tag_changelog")
  end
end

shared_examples_for 'an invalid RPM changelog processor' do |project|
  it 'should reject the RPM changelog' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/#{project}; #{rake_cmd} pkg:check_rpm_changelog"),
      :acceptable_exit_codes => [1]
  end

  it 'should not generate the tag changelog' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/#{project}; #{rake_cmd} pkg:create_tag_changelog"),
      :acceptable_exit_codes => [1]
  end
end

describe 'rake pkg:check_rpm_changelog' do
  before :all do
    copy_host_files_into_build_user_homedir(hosts)
  end


  hosts.each do |_host|
    context "on #{_host}" do
      let!(:host){ _host }
      let(:pkg_root_dir) { '/home/build_user/host_files/spec/acceptance/files' }

      it 'can prep the package directories' do
        testpackages = [
          'asset',
          'asset_with_misordered_entries',
          'module',
          'module_with_misordered_entries'
        ]

        testpackages.each do |package|
          on hosts, %Q(#{run_cmd} "cd #{pkg_root_dir}/#{package}; ) +
                    %Q(rvm use default; bundle update --local || bundle update")
        end
      end

      context 'with no project changelog errors' do
        it_should_behave_like('a valid RPM changelog processor', 'asset')
        it_should_behave_like('a valid RPM changelog processor', 'module')
      end


      context 'with project changelog errors' do
        it_should_behave_like('an invalid RPM changelog processor', 'asset_with_misordered_entries')
        it_should_behave_like('an invalid RPM changelog processor', 'module_with_misordered_entries')
      end
    end
  end
end
