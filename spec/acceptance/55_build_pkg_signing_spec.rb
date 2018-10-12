require 'spec_helper_acceptance'
require_relative 'support/build_user_helpers'
require_relative 'support/build_project_helpers'

RSpec.configure do |c|
  c.include Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers
  c.include Simp::BeakerHelpers::SimpRakeHelpers::BuildProjectHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::BuildProjectHelpers
end

describe 'rake pkg:signrpms' do
  def opts
    { run_in_parallel: true, environment: { 'SIMP_PKG_verbose' => 'yes' } }
  end

  # Clean out RPMs dir and copy in a fresh dummy RPM
  def prep_rpms_dir(rpms_dir, src_rpms, opts = {})
    copy_cmds = src_rpms.map { |_rpm| "cp -a '#{_rpm}' '#{rpms_dir}'" }.join('; ')
    on(hosts, %(#{run_cmd} "rm -f '#{rpms_dir}/*'; #{copy_cmds} "), opts)
  end

  # Provides a scaffolded test project and `let` variables
  shared_context 'a freshly-scaffolded test project' do |dir|
    opts = {}
    test__dir  = "#{build_user_homedir}/test--#{dir}"
    rpms__dir  = "#{test__dir}/test.rpms"
    src__rpm   =  "#{build_user_host_files}/spec/lib/simp/files/testpackage-1-0.noarch.rpm"
    host__dirs = {}

    hosts.each do |host|
      dist_dir = distribution_dir(host, test__dir, opts)
      host__dirs[host] = {
        test_dir:  test__dir,
        dev_keydir: "#{dist_dir}/build_keys/dev",
        dvd_dir: "#{dist_dir}/DVD",
      }
      host__dirs[host.name] = host__dirs[host]
    end

    before(:all) do
      # Scaffold a project skeleton
      scaffold_build_project(hosts, test__dir, opts)

      # Provide an RPM directory to process and a dummy RPM to sign
      on(hosts, %(#{run_cmd} "mkdir '#{rpms__dir}'"))

      # Ensure a DVD directory exists that is appropriate to each SUT
      hosts.each do |host|
        on(host, %(#{run_cmd} "mkdir -p '#{host__dirs[host][:dvd_dir]}'"), opts)
      end
    end

    let(:test_dir) { test__dir }
    let(:rpms_dir) { rpms__dir }
    let(:src_rpm) { src__rpm }
    let(:test_rpm) { "#{rpms__dir}/#{File.basename(src__rpm)}" }
    let(:dirs) { host__dirs }
  end

  let(:rpm_unsigned_regex) do
    %r{^Signature\s+:\s+\(none\)$}
  end

  let(:rpm_signed_regex) do
    %r{^Signature\s+:\s+.*,\s*Key ID (?<key_id>[0-9a-f]+)$}
  end

  let(:expired_keydir) do
    "#{build_user_host_files}/spec/acceptance/files/build/pkg/gpg-keydir.expired.2018-04-06"
  end

  shared_examples 'it creates a new GPG dev signing key' do
    it 'creates a new GPG dev signing key' do
      on(hosts, %(#{run_cmd} "cd '#{test_dir}'; bundle exec rake pkg:signrpms[dev,'#{rpms_dir}']"), opts)
      hosts.each do |host|
        expect { dev_signing_key_id(host, test_dir, opts) }.not_to(raise_error)
      end
    end
  end

  shared_examples 'it begins with unsigned RPMs' do
    it 'begins with unsigned RPMs' do
      prep_rpms_dir(rpms_dir, [src_rpm], opts)
      rpms_before_signing = on(hosts, %(#{run_cmd} "rpm -qip '#{test_rpm}' | grep ^Signature"), opts)
      rpms_before_signing.each do |result|
        expect(result.stdout).to match rpm_unsigned_regex
      end
    end
  end

  shared_examples 'it signs RPM packages in the directory using the GPG dev signing key' do
    it 'signs RPM packages in the directory using the GPG dev signing key' do
      on(hosts, %(#{run_cmd} "cd '#{test_dir}'; bundle exec rake pkg:signrpms[dev,'#{rpms_dir}']"), opts)
      rpms_after_signing = on(hosts, %(#{run_cmd} "rpm -qip '#{test_rpm}' | grep ^Signature"), opts)
      rpms_after_signing.each do |result|
        host = hosts_with_name(hosts, result.host).first
        on(host, "gpg --list-keys --homedir='#{dirs[host][:dev_keydir]}'", opts)

        expect(result.stdout).to match rpm_signed_regex
        signed_rpm_data = rpm_signed_regex.match(result.stdout)
        expect(signed_rpm_data[:key_id]).to eql dev_signing_key_id(host, test_dir, opts)
      end
    end
  end

  describe 'when starting without a dev key' do
    include_context('a freshly-scaffolded test project', 'pkg-signrpms')
    include_examples('it creates a new GPG dev signing key')
    include_examples('it begins with unsigned RPMs')
    include_examples('it signs RPM packages in the directory using the GPG dev signing key')

    context 'when there is an unexpired GPG dev signing key' do
      include_examples('it begins with unsigned RPMs')
      include_examples('it signs RPM packages in the directory using the GPG dev signing key')
    end
  end

  describe 'when starting with an expired dev key' do
    include_context('a freshly-scaffolded test project', 'pkg-signrpms-expired_dev_key')

    it 'begins with an expired GPG signing key' do
      prep_rpms_dir(rpms_dir, [src_rpm], opts)
      hosts.each do |host|
        copy_expired_keydir_to_dev_cmds = [
          "mkdir -p '$(dirname '#{dirs[host][:dev_keydir]}')'",
          "cp -aT '#{expired_keydir}' '#{dirs[host][:dev_keydir]}'",
          "ls -lart '#{expired_keydir}'"
        ].join(' && ')
        on(host, %(#{run_cmd} "#{copy_expired_keydir_to_dev_cmds}"), opts)
        result = on(host, %(#{run_cmd} "gpg --list-keys --homedir='#{dirs[host][:dev_keydir]}'"), opts)
        expect(result.stdout).to match(/expired: 2018-04-06/)
      end
    end

    include_examples('it creates a new GPG dev signing key')
    include_examples('it begins with unsigned RPMs')
    include_examples('it signs RPM packages in the directory using the GPG dev signing key')
  end
end
