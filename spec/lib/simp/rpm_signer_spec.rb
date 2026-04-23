# frozen_string_literal: true

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

  let(:verbose) { ENV['VERBOSE'].to_s =~ %r{^(yes|true)$} }
  let(:gpg_email_name) { 'gatekeeper@simp.development.key' }
  let(:passphrase) { 'dev_passphrase' }
  let(:key_id) { '722B97A808E7DAEA' }
  let(:key_size) { 4096 }
  let(:key_info) do
    {
      :dir => @gpg_keydir,
      :name => gpg_email_name,
      :key_id => key_id,
      :key_size => key_size,
      :password => passphrase
    }
  end

  let(:gpg_cmd) { "gpg --with-colons --homedir=#{@gpg_keydir} --list-keys '<#{gpg_email_name}>' 2>&1" }
  let(:key_list_output) do
    <<~EOM
        tru::1:1521838828:0:3:1:5
        pub:e:4096:1:722B97A808E7DAEA:1521838554:1523048154::-:::sc::::::23::0:
        fpr:::::::::5DD3E8D45C99780DCA7D0B83722B97A808E7DAEA:
        uid:e::::1521838554::773C55CA511CCE31244D86D4AB70F6499024695F::SIMP Development (Development key 1521838554) <gatekeeper@simp.development.key>::::::::::0:
    EOM
  end

  # The bulk of load_key is tested in the acceptance test. These tests are
  # a few edge cases.
  describe '.load_key' do
    context 'key info missing from files' do
      before :each do
        allow(described_class).to receive(:which).with('gpg').and_return('/usr/bin/gpg')
        FileUtils.mkdir_p(@gpg_keydir)
      end

      after :each do
        FileUtils.rm_rf(@gpg_keydir)
        described_class.clear_gpg_keys_cache
      end

      it 'prompts user for key email and passphrase when not in files' do
        expect($stdin).to receive(:gets).and_return(gpg_email_name, passphrase)
        expect(described_class).to receive(:`).with(gpg_cmd).and_return(key_list_output)

        expect(described_class.load_key(@gpg_keydir, verbose)).to eq(key_info)

        # verifies returning info from the cache, otherwise user would be prompted again
        # and expectation on $stdin would fail
        expect(described_class.load_key(@gpg_keydir, verbose)).to eq(key_info)
      end

      it "reads the passphrase from the 'password' file" do
        File.open(File.join(@gpg_keydir, 'password'), 'w') { |file| file.puts passphrase }
        expect($stdin).to receive(:gets).and_return(gpg_email_name)
        expect(described_class).to receive(:`).with(gpg_cmd).and_return(key_list_output)

        expect(described_class.load_key(@gpg_keydir, verbose)).to eq(key_info)
      end
    end

    context 'errors' do
      it 'fails when gpg does not exist' do
        expect(described_class).to receive(:which).with('gpg').and_return(nil)
        expect { described_class.load_key(@gpg_keydir, verbose) }.to raise_error(
          %r{Cannot sign RPMs without 'gpg'},
        )
      end

      it 'fails when keydir does not exist' do
        expect(described_class).to receive(:which).with('gpg').and_return('/usr/bin/gpg')
        expect { described_class.load_key(@gpg_keydir, verbose) }.to raise_error(
          %r{Could not find GPG keydir},
        )
      end

      it 'fails when key info cannot be retrieved via gpg' do
        FileUtils.mkdir_p(@gpg_keydir)
        expect(described_class).to receive(:which).with('gpg').and_return('/usr/bin/gpg')
        expect($stdin).to receive(:gets).and_return(gpg_email_name, passphrase)
        expect(described_class).to receive(:`).with(gpg_cmd).and_return('')

        expect { described_class.load_key(@gpg_keydir, verbose) }.to raise_error(
          %r{Error getting GPG key ID or Key size metadata},
        )
      end
    end
  end
end
