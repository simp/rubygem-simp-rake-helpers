require 'spec_helper_acceptance'
require_relative 'support/build_user_helpers'

RSpec.configure do |c|
  c.include Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers
end

# These spec tests are run from inside beaker nodesets because the logic
# Simp::LocalGpgSigningKey relies heavily on the behavior of the local OS's
# `gpg` and `gpg-agent` commands.  Historically, these have caused us some
# grief due to minor inconsistencies between versions of  gpg/gpg2/gpg-agent.
#
# It should be possible manage GPG keys using this logic from many OSes,
# but it's silly to try to mock them all directly in RSpec.
describe 'rake pkg:rpm with customized content' do

  def hf_cmd( hosts, cmd, env_str=nil, opts={})
    if ENV['PUPPET_VERSION']
      env_str ||= %(export PUPPET_VERSION='#{ENV['PUPPET_VERSION']}';)
    end
    on hosts, %(#{run_cmd} "cd /home/build_user/host_files; #{env_str} #{cmd}"), opts
  end

  before :all do
    copy_host_files_into_build_user_homedir(hosts)
    hf_cmd(hosts, "bundle --local || bundle", nil, {run_in_parallel: true})
  end

  it 'can run the os-dependent Simp::LocalGpgSigningKey spec tests' do
    hf_cmd( hosts, "bundle exec rspec spec/lib/simp/local_gpg_signing_key_spec.rb.beaker-only" );
  end
end

