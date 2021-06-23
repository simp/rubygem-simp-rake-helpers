require 'spec_helper_acceptance'
require_relative 'support/build_user_helpers'
require_relative 'support/build_project_helpers'

RSpec.configure do |c|
  c.include Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers
  c.include Simp::BeakerHelpers::SimpRakeHelpers::BuildProjectHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::BuildProjectHelpers
end

# options to be applied to each on() operation
def run_opts
  # WARNING: If you set run_in_parallel to true, tests will fail
  # when run in a GitHub action.
  { run_in_parallel: false }
end

describe 'rake pkg:signrpms and pkg:checksig' do

  # Clean out RPMs dir and copy in a fresh dummy RPM
  def prep_rpms_dir(rpms_dir, src_rpms, opts = {})
    copy_cmds = src_rpms.map { |_rpm| "cp -a '#{_rpm}' '#{rpms_dir}'" }.join('; ')
    on(hosts, %(#{run_cmd} "rm -f '#{rpms_dir}/*'; #{copy_cmds} "), opts)
  end

  # Provides a scaffolded test project and `let` variables
  shared_context 'a freshly-scaffolded test project' do |dir, opts = {}|
    test__dir     = "#{build_user_homedir}/test-#{dir}"
    rpms__dir     = "#{test__dir}/test.rpms"
    src__rpm      =  "#{build_user_host_files}/spec/lib/simp/files/testpackage-1-1.noarch.rpm"
    host__dirs    = {}
    gpg__keysdir  = opts[:gpg_keysdir] ? opts[:gpg_keysdir] : "#{test__dir}/.dev_gpgkeys"
    extra__env    = opts[:gpg_keysdir] ? "SIMP_PKG_build_keys_dir=#{gpg__keysdir}" : ''
    digest__algo  = opts[:digest_algo] ? opts[:digest_algo] : nil


    hosts.each do |host|
      dist_dir = distribution_dir(host, test__dir, run_opts)
      host__dirs[host] = {
        test_dir:  test__dir,
        dvd_dir: "#{dist_dir}/DVD"
      }
      host__dirs[host.name] = host__dirs[host]
    end

    before(:all) do
      # Scaffold a project skeleton
      scaffold_build_project(hosts, test__dir, run_opts)

      # Provide an RPM directory to process
      on(hosts, %(#{run_cmd} "mkdir '#{rpms__dir}'"), run_opts)

      # Ensure a DVD directory exists that is appropriate to each SUT
      hosts.each do |host|
        on(host, %(#{run_cmd} "mkdir -p '#{host__dirs[host][:dvd_dir]}'"), run_opts)
      end
    end

    let(:test_dir) { test__dir }
    let(:rpms_dir) { rpms__dir }
    let(:src_rpm) { src__rpm }
    let(:test_rpm) { "#{rpms__dir}/#{File.basename(src__rpm)}" }
    let(:dirs) { host__dirs }
    let(:dev_keydir) { "#{gpg__keysdir}/dev" }
    let(:extra_env) { extra__env }
    let(:digest_algo_param) { digest__algo }
    let(:digest_algo_result) { digest__algo ? digest__algo.upcase : 'SHA256'  }
    let(:signrpm_cmd) {
      extra_args = digest_algo_param ? ",false,#{digest_algo_param}" : ''
      "SIMP_PKG_verbose=yes #{extra_env} bundle exec rake pkg:signrpms[dev,'#{rpms_dir}'#{extra_args}]"
    }
    let(:checksig_cmd) { "#{extra_env} bundle exec rake pkg:checksig[#{rpms_dir}]" }
  end

  let(:rpm_unsigned_regex) do
    %r{^Signature\s+:\s+\(none\)$}
  end

  let(:rpm_signed_regex) do
    %r{^Signature\s+:\s+\w+/(?<digest_algo>.*?),.*,\s*Key ID (?<key_id>[0-9a-f]+)$}
  end

  let(:expired_keydir) do
    # NOTE: This expired keydir actually works on EL7 and EL8, even though
    # the newer gpg version creates different files than those in this
    # directory.
    "#{build_user_host_files}/spec/acceptance/files/build/pkg/gpg-keydir.expired.2018-04-06"
  end

  shared_examples 'it does not leave the gpg-agent daemon running' do
    it 'does not leave the gpg-agent daemon running' do
      hosts.each do |host|
        expect(gpg_agent_running?(host, dev_keydir)).to be false
      end
    end
  end

  shared_examples 'it verifies RPM signatures' do
    let(:public_gpgkeys_dir) { 'src/assets/gpgkeys/GPGKEYS' }
    it 'verifies RPM signatures' do
      hosts.each do |host|
        # mock out the simp-gpgkeys project checkout so that the pkg:checksig
        # doesn't fail before reading in the generated 'dev' GPGKEY
        on(host, %(#{run_cmd} "cd '#{test_dir}'; mkdir -p #{public_gpgkeys_dir}"), run_opts)
        on(host, %(#{run_cmd} "cd '#{test_dir}'; touch #{public_gpgkeys_dir}/RPM-GPG-KEY-empty"), run_opts)
        on(host, %(#{run_cmd} "cd '#{test_dir}'; #{checksig_cmd}"), run_opts)
      end
    end
  end

  shared_examples 'it creates a new GPG dev signing key' do
    it 'creates a new GPG dev signing key' do
      on(hosts, %(#{run_cmd} "cd '#{test_dir}'; #{signrpm_cmd}"), run_opts)
      hosts.each do |host|
        expect(dev_signing_key_id(host, dev_keydir, run_opts)).to_not be_empty
        expect(file_exists_on(host,"#{dirs[host][:dvd_dir]}/RPM-GPG-KEY-SIMP-Dev")).to be true
      end
    end

    include_examples('it does not leave the gpg-agent daemon running')
  end

  shared_examples 'it begins with unsigned RPMs' do
    it 'begins with unsigned RPMs' do
      prep_rpms_dir(rpms_dir, [src_rpm], run_opts)
      rpms_before_signing = on(hosts, "rpm -qip '#{test_rpm}' | grep ^Signature", run_opts)
      rpms_before_signing.each do |result|
        expect(result.stdout).to match rpm_unsigned_regex
      end
    end
  end

  shared_examples 'it creates GPG dev signing key and signs packages' do
    it 'creates GPG dev signing key and signs packages' do
      hosts.each do |host|
        # NOTE: pkg:signrpms will not actually fail if it can't sign a RPM
        on(hosts, %(#{run_cmd} "cd '#{test_dir}'; #{signrpm_cmd}"), run_opts)

        expect(file_exists_on(host,"#{dirs[host][:dvd_dir]}/RPM-GPG-KEY-SIMP-Dev")).to be true

        result = on(host, "rpm -qip '#{test_rpm}' | grep ^Signature", run_opts)
        expect(result.stdout).to match rpm_signed_regex
        signed_rpm_data = rpm_signed_regex.match(result.stdout)
        expect(signed_rpm_data[:key_id]).to eql dev_signing_key_id(host, dev_keydir, run_opts)
        expect(signed_rpm_data[:digest_algo]).to eql digest_algo_result
      end
    end

    include_examples('it does not leave the gpg-agent daemon running')
  end

  shared_examples 'it signs RPM packages using existing GPG dev signing key' do
    it 'signs RPM packages using existing GPG dev signing key' do
      hosts.each do |host|
        existing_key_id = dev_signing_key_id(host, dev_keydir, run_opts)

        on(hosts, %(#{run_cmd} "cd '#{test_dir}'; #{signrpm_cmd}"), run_opts)

        result = on(host, "rpm -qip '#{test_rpm}' | grep ^Signature", run_opts)
        expect(result.stdout).to match rpm_signed_regex
        signed_rpm_data = rpm_signed_regex.match(result.stdout)
        expect(signed_rpm_data[:key_id]).to eql existing_key_id
        expect(signed_rpm_data[:digest_algo]).to eql digest_algo_result
      end
    end

    include_examples('it does not leave the gpg-agent daemon running')
  end


  describe 'when starting without a dev key and no RPMs to sign' do
    include_context('a freshly-scaffolded test project', 'create-key')
    include_examples('it creates a new GPG dev signing key')
  end

  describe 'when starting without a dev key and RPMs to sign' do
    include_context('a freshly-scaffolded test project', 'signrpms')
    include_examples('it begins with unsigned RPMs')
    include_examples('it creates GPG dev signing key and signs packages')
    include_examples('it verifies RPM signatures')

    context 'when there is an unexpired GPG dev signing key and the packages are unsigned' do
      include_examples('it begins with unsigned RPMs')
      include_examples('it signs RPM packages using existing GPG dev signing key')
      include_examples('it verifies RPM signatures')
    end
  end

  describe 'when starting with an expired dev key' do
    include_context('a freshly-scaffolded test project', 'signrpms-expired')

    it 'begins with an expired GPG signing key' do
      prep_rpms_dir(rpms_dir, [src_rpm], run_opts)
      hosts.each do |host|
        copy_expired_keydir_to_dev_cmds = [
          "mkdir -p '$(dirname '#{dev_keydir}')'",
          "cp -aT '#{expired_keydir}' '#{dev_keydir}'",
          "ls -lart '#{expired_keydir}'"
        ].join(' && ')
        on(host, %(#{run_cmd} "#{copy_expired_keydir_to_dev_cmds}"), run_opts)
        result = on(host, %(#{run_cmd} "gpg --list-keys --homedir='#{dev_keydir}'"), run_opts)
        expect(result.stdout).to match(/expired: 2018-04-06/)
      end
    end

    include_examples('it begins with unsigned RPMs')
    include_examples('it creates GPG dev signing key and signs packages')
    include_examples('it verifies RPM signatures')
  end

  describe 'when packages are already signed' do
    let(:keysdir)  { "#{test_dir}/.dev_gpgkeys" }

    include_context('a freshly-scaffolded test project', 'force')

    context 'initial package signing' do
      include_examples('it begins with unsigned RPMs')
      include_examples('it creates GPG dev signing key and signs packages')
    end

    context 'when force is disabled' do
      before :each do
        # remove the initial signing key
        on(hosts, %(#{run_cmd} 'rm -rf #{keysdir}'))
      end

      it 'creates new GPG signing key but does not resign RPMs' do
        hosts.each do |host|
          # force defaults to false
          on(host, %(#{run_cmd} "cd '#{test_dir}'; bundle exec rake pkg:signrpms[dev,'#{rpms_dir}']"), run_opts)

          result = on(host, "rpm -qip '#{test_rpm}' | grep ^Signature", run_opts)
          expect(result.stdout).to match rpm_signed_regex
          signed_rpm_data = rpm_signed_regex.match(result.stdout)

          # verify RPM is not signed with the new signing key
          expect(signed_rpm_data[:key_id]).to_not eql dev_signing_key_id(host, dev_keydir, run_opts)
        end
      end

      it 'does not verify RPM signatures with the new key' do
        public_gpgkeys_dir = 'src/assets/gpgkeys/GPGKEYS'
        hosts.each do |host|
          # mock out the simp-gpgkeys project checkout so that the pkg:checksig
          # doesn't fail before reading in the new generated 'dev' GPGKEY
          on(host, %(#{run_cmd} "cd '#{test_dir}'; mkdir -p #{public_gpgkeys_dir}"), run_opts)
          on(host, %(#{run_cmd} "cd '#{test_dir}'; touch #{public_gpgkeys_dir}/RPM-GPG-KEY-empty"), run_opts)
          result = on(host, %(#{run_cmd} "cd '#{test_dir}'; #{checksig_cmd}"),
            :acceptable_exit_codes => [1]
          )

          expect(result.stderr).to match('ERROR: Untrusted RPMs found in the repository')
        end
      end
    end

    context 'when force is enabled' do
      before :each do
        # remove the initial signing key
        on(hosts, %(#{run_cmd} 'rm -rf #{keysdir}'))
      end

      it 'creates new GPG signing key and resigns RPMs' do
        hosts.each do |host|
          on(host, %(#{run_cmd} "cd '#{test_dir}'; bundle exec rake pkg:signrpms[dev,'#{rpms_dir}',true]"), run_opts)

          result = on(host, "rpm -qip '#{test_rpm}' | grep ^Signature", run_opts)
          expect(result.stdout).to match rpm_signed_regex
          signed_rpm_data = rpm_signed_regex.match(result.stdout)

          # verify RPM is signed with the new signing key
          expect(signed_rpm_data[:key_id]).to eql dev_signing_key_id(host, dev_keydir, run_opts)
        end
      end
    end
  end

  describe 'when SIMP_PKG_build_keys_dir is set' do
    opts = { :gpg_keysdir => '/home/build_user/.dev_gpgpkeys' }
    include_context('a freshly-scaffolded test project', 'custom-keys-dir', opts)
    include_examples('it begins with unsigned RPMs')
    include_examples('it creates GPG dev signing key and signs packages')
  end

  describe 'when digest algorithm is specified' do
    opts = { :digest_algo => 'sha384' }
    include_context('a freshly-scaffolded test project', 'custom-digest-algo', opts)
    include_examples('it begins with unsigned RPMs')
    include_examples('it creates GPG dev signing key and signs packages')
    include_examples('it verifies RPM signatures')
  end

  describe 'when some rpm signing fails' do
    include_context('a freshly-scaffolded test project', 'signing-failure')
    include_examples('it begins with unsigned RPMs')

    it 'should create a malformed RPM' do
      on(hosts, %(#{run_cmd} "echo 'OOPS' > #{rpms_dir}/oops-test.rpm"))
    end

    it 'should sign all valid RPMs before failing' do
      hosts.each do |host|
        result = on(host,
          %(#{run_cmd} "cd '#{test_dir}'; SIMP_PKG_verbose="yes" #{signrpm_cmd}"),
         :acceptable_exit_codes => [1]
        )

        expect(result.stderr).to match('ERROR: Failed to sign some RPMs')

        signature_check = on(host, "rpm -qip '#{test_rpm}' | grep ^Signature", run_opts)
        expect(signature_check.stdout).to match rpm_signed_regex
      end
    end
  end

  describe 'when wrong keyword password is specified' do
    include_context('a freshly-scaffolded test project', 'wrong-password')
    include_examples('it creates a new GPG dev signing key')

    it 'should corrupt the password of new key' do
      key_gen_file = File.join(dev_keydir, 'gengpgkey')
      on(hosts, "sed -i -e \"s/^Passphrase: /Passphrase: OOPS/\" #{key_gen_file}")
    end

    include_examples('it begins with unsigned RPMs')

    it 'should fail to sign any rpms and notify user of each failure' do
      hosts.each do |host|
        result = on(host,
          %(#{run_cmd} "cd '#{test_dir}'; SIMP_PKG_verbose="yes" #{signrpm_cmd}"),
         :acceptable_exit_codes => [1]
        )

        err_msg = %r(Error occurred while attempting to sign #{test_rpm})
        expect(result.stderr).to match(err_msg)

        signature_check = on(host, "rpm -qip '#{test_rpm}' | grep ^Signature", run_opts)
        expect(signature_check.stdout).to match rpm_unsigned_regex
      end
    end
  end

  hosts.each do |host|
    os_major =  fact_on(host,'operatingsystemmajrelease')
    if os_major > '7'
      # this problem only happens on EL > 7 in a docker container
      describe "when gpg-agent's socket path is too long on #{host}" do
        opts = { :gpg_keysdir => '/home/build_user/this/results/in/a/gpg_agent/socket/path/that/is/longer/than/one/hundred/eight/characters' }
        include_context('a freshly-scaffolded test project', 'long-socket-path', opts)

        context 'when the gpg key needs to be created ' do
          it 'should fail to sign any rpms' do
            on(host,
               %(#{run_cmd} "cd '#{test_dir}'; SIMP_PKG_verbose="yes" #{signrpm_cmd}"),
              :acceptable_exit_codes => [1]
            )
          end
        end

        context 'when the gpg key already exists' do
          # This would be when a GPG key dir was populated with keys generated elsewhere.
          # Reuse the keys from an earlier test.
          it 'should copy existing key files into the gpg key dir' do
            source_dir = '/home/build_user/test-create-key/.dev_gpgkeys/dev'
            on(host, %(#{run_cmd} "cp -r #{source_dir}/* #{dev_keydir}"))
          end

          include_examples('it begins with unsigned RPMs')

          it 'should fail to sign any rpms and notify user of each failure' do
            # For rpm-sign-4.14.2-11.el8_0, 'rpm --resign' hangs instead of failing
            # when gpg-agent fails to start.
            # Set the default smaller than the 30 second default, so that we don't
            # wait so long for the failure.
            result = on(host,
              %(#{run_cmd} "cd '#{test_dir}'; SIMP_PKG_rpmsign_timeout=5 SIMP_PKG_verbose="yes" #{signrpm_cmd}"),
              :acceptable_exit_codes => [1]
            )

            err_msg = %r(Failed to sign #{test_rpm} in 5 seconds)
            expect(result.stderr).to match(err_msg)

            signature_check = on(host, "rpm -qip '#{test_rpm}' | grep ^Signature", run_opts)
            expect(signature_check.stdout).to match rpm_unsigned_regex
          end
        end
      end
    end
  end
end
