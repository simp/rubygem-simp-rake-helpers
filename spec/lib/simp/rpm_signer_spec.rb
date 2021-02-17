require 'simp/rpm_signer'
require 'spec_helper'
require 'fileutils'
require 'tmpdir'


describe Simp::RpmSigner do

  before :all do
    @tmp_dir = Dir.mktmpdir('spec_test__rpm_signer')
    @gpg_keydir = File.join(@tmp_dir, 'dev')
  end

  after :all do
    FileUtils.remove_entry_secure(@tmp_dir)
  end

  let(:verbose) { ENV['VERBOSE'].to_s =~ /^(yes|true)$/ }
  let(:gpg_email_name) { 'gatekeeper@simp.development.key' }
  let(:passphrase) { 'dev_passphrase' }
  let(:key_id) { '722B97A808E7DAEA' }
  let(:key_size) { 4096 }
  let(:key_info) { {
    :dir      => @gpg_keydir,
    :name     => gpg_email_name,
    :key_id   => key_id,
    :key_size => key_size,
    :password => passphrase
  } }

  let(:gpg_cmd) {  "gpg --with-colons --homedir=#{@gpg_keydir} --list-keys '<#{gpg_email_name}>' 2>&1" }
  let(:key_list_output) { <<~EOM
        tru::1:1521838828:0:3:1:5
        pub:e:4096:1:722B97A808E7DAEA:1521838554:1523048154::-:::sc::::::23::0:
        fpr:::::::::5DD3E8D45C99780DCA7D0B83722B97A808E7DAEA:
        uid:e::::1521838554::773C55CA511CCE31244D86D4AB70F6499024695F::SIMP Development (Development key 1521838554) <gatekeeper@simp.development.key>::::::::::0:
      EOM
  }

  # The bulk of load_key is tested in the acceptance test. These tests are
  # a few edge cases.
  context '.load_key' do
    context 'key info missing from files' do
      before :each do
        allow(Simp::RpmSigner).to receive(:which).with('gpg').and_return('/usr/bin/gpg')
        FileUtils.mkdir_p(@gpg_keydir)
      end

      after :each do
        FileUtils.rm_rf(@gpg_keydir)
        Simp::RpmSigner.clear_gpg_keys_cache
      end

      it 'should prompt user for key email and passphrase when not in files' do
        expect($stdin).to receive(:gets).and_return(gpg_email_name, passphrase)
        expect(Simp::RpmSigner).to receive(:`).with(gpg_cmd).and_return(key_list_output)

        expect(Simp::RpmSigner.load_key(@gpg_keydir, verbose)).to eq (key_info)

        # verifies returning info from the cache, otherwise user would be prompted again
        # and expectation on $stdin would fail
        expect(Simp::RpmSigner.load_key(@gpg_keydir, verbose)).to eq (key_info)
      end

      it "should read the passphrase from the 'password' file" do
        File.open(File.join(@gpg_keydir, 'password'),'w') { |file| file.puts passphrase }
        expect($stdin).to receive(:gets).and_return(gpg_email_name)
        expect(Simp::RpmSigner).to receive(:`).with(gpg_cmd).and_return(key_list_output)

        expect(Simp::RpmSigner.load_key(@gpg_keydir, verbose)).to eq (key_info)
      end
    end

    context 'errors' do
      it 'should fail when gpg does not exist' do
        expect(Simp::RpmSigner).to receive(:which).with('gpg').and_return(nil)
        expect { Simp::RpmSigner.load_key(@gpg_keydir, verbose) }.to raise_error(
          /Cannot sign RPMs without 'gpg'/)
      end

      it 'should fail when keydir does not exist' do
        expect(Simp::RpmSigner).to receive(:which).with('gpg').and_return('/usr/bin/gpg')
        expect { Simp::RpmSigner.load_key(@gpg_keydir, verbose) }.to raise_error(
          /Could not find GPG keydir/)
      end

      it 'should fail when key info cannot be retrieved via gpg' do
        FileUtils.mkdir_p(@gpg_keydir)
        expect(Simp::RpmSigner).to receive(:which).with('gpg').and_return('/usr/bin/gpg')
        expect($stdin).to receive(:gets).and_return(gpg_email_name, passphrase)
        expect(Simp::RpmSigner).to receive(:`).with(gpg_cmd).and_return('')

        expect { Simp::RpmSigner.load_key(@gpg_keydir, verbose) }.to raise_error(
          /Error getting GPG key ID or Key size metadata/)
      end
    end
  end
end
