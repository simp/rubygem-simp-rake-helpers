require 'spec_helper_acceptance'
require_relative 'support/build_user_helpers'

RSpec.configure do |c|
  c.include Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers
end
#####
# ####def build_user_on(hosts, cmd, env_str = nil, opts = {})
#####  if ENV['PUPPET_VERSION']
#####    env_str ||= %(export PUPPET_VERSION='#{ENV['PUPPET_VERSION']}';)
#####  end
#####  on hosts, %(#{run_cmd} "cd #{build_user_homedir}; rvm use default; #{env_str} #{cmd}"), opts
# ####end

def scaffold_build_project(hosts, test_dir, opts)
  copy_host_files_into_build_user_homedir(hosts, opts)
  skeleton_dir = "#{build_user_host_files}/spec/acceptance/files/build/project_skeleton/"

  on(hosts, %(mkdir "#{test_dir}"; chown build_user:build_user "#{test_dir}"), opts)
  on(hosts, %(#{run_cmd} "cp -aT '#{skeleton_dir}' '#{test_dir}'"), opts)
  gemfile = <<-GEMFILE.gsub(%r{^ {6}}, '')
    gem_sources = ENV.fetch('GEM_SERVERS','https://rubygems.org').split(/[, ]+/)
    gem_sources.each { |gem_source| source gem_source }
    gem 'simp-rake-helpers', :path => '#{build_user_host_files}'
    gem 'simp-build-helpers', ENV.fetch('SIMP_BUILD_HELPERS_VERSION', '>= 0.1.0')
    ###gem 'facter', '>= 2.0'
  GEMFILE
  create_remote_file(hosts, "#{test_dir}/Gemfile", gemfile, opts)
  on(hosts, "chown build_user:build_user #{test_dir}/Gemfile", opts)
  on(hosts, %(#{run_cmd} "cd '#{test_dir}'; rvm use default; bundle --local || bundle"), opts)
end

def opts
  { run_in_parallel: true, environment: { 'SIMP_PKG_verbose' => 'yes' } }
end

def distribution_dir(host, opts={})
  @distribution_dirs ||= {}
  return @distribution_dirs[host.to_s] if  @distribution_dirs.key?(host.to_s)
  result = on(host, %(#{run_cmd} "rvm use default; facter --json"), opts)
  facts = JSON.parse(result.stdout.lines[1..-1].join)
  dir = "#{@test_dir}/build/distributions/#{os['name']}/" \
            "#{os['release']['major']}/#{facts['architecture']}"
  @distribution_dirs[host.to_s] = dir
end


describe 'rake pkg:signrpms' do
  before :all do
    @test_dir = "#{build_user_homedir}/test--pkg-signrpms"

    scaffold_build_project(hosts, @test_dir, opts)

    # Provide an RPM directory to process and a dummy RPM to sign
    @rpms_dir = "#{@test_dir}/test.rpms"
    @src_rpm  = "#{build_user_host_files}/spec/lib/simp/files/testpackage-1-0.noarch.rpm"
    @test_rpm = File.join(@rpms_dir, File.basename(@src_rpm))
    on(hosts, %(#{run_cmd} "mkdir '#{@rpms_dir}'"))

    # Ensure a DVD directory exists that is appropriate to each SUT
    hosts.each do |host|
      dvd_dir = distribution_dir(host, opts) + "/DVD"
      on(host, %(#{run_cmd} "mkdir -p #{dvd_dir}"), opts)
    end
  end

  it 'signs packages ' do
    # Clean out RPMs dir and copy in a fresh dummy RPM
    on(hosts, %(#{run_cmd} "rm -f '#{@rpms_dir}/*'; cp -a '#{@src_rpm}' '#{@test_rpm}'"), opts)

    rpms_before_signing = on(hosts, %(#{run_cmd} "rpm -qip '#{@test_rpm}' | grep ^Signature"), opts)
    rpms_before_signing.each { |result| expect(result.stdout).to match %r{^Signature\s+:\s+\(none\)$} }

    on(hosts, %(#{run_cmd} "cd '#{@test_dir}'; bundle exec rake pkg:signrpms[dev,'#{@rpms_dir}']"), opts)

    rpms_after_signing = on(hosts, %(#{run_cmd} "rpm -qip '#{@test_rpm}' | grep ^Signature"), opts)
    rpms_after_signing.each do |result|
      regex = %r{^Signature\s+:\s+.*,\s*Key ID (?<key_id>[0-9a-f]+)$}
      expect(result.stdout).to match regex
      match = regex.match(result.stdout)
      host = hosts_with_name(hosts, result.host).first
      require 'pry'; binding.pry
    end

    require 'pry'; binding.pry
  end

  ###  it 'can run the os-dependent Simp::LocalGpgSigningKey spec tests' do
  ###    hf_cmd(hosts, 'bundle exec rspec spec/lib/simp/local_gpg_signing_key_spec.rb.beaker-only')
  ###  end
end
