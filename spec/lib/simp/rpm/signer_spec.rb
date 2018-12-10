require 'simp/rpm/signer'
require 'spec_helper'
require 'tmpdir'

describe Simp::Rpm::Signer do
  before :all do
    @tmp_dir = Dir.mktmpdir(File.basename(__FILE__))
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )

    FileUtils.cp_r(File.join(@files_dir, 'dev'), @tmp_dir)
    @key_dir = File.join(@tmp_dir, 'dev')
    @key_id  = '91c40758e5fed7d1'

    FileUtils.cp_r(File.join(@files_dir, 'dev2'), @tmp_dir)
    @key_dir2 = File.join(@tmp_dir, 'dev2')
    @key_id2  = 'e99878a4d89f1d04'
  end

  after :all do
    FileUtils.remove_entry_secure @tmp_dir
  end

  let(:orig_rpms) do
    [
      File.join(@files_dir, 'pupmod-simp-beakertest-0.0.1-0.noarch.rpm'), # unsigned
      File.join(@files_dir, 'pupmod-simp-beakertest-0.0.2-0.noarch.rpm'), # signed by dev
      File.join(@files_dir, 'pupmod-simp-beakertest-0.0.3-0.noarch.rpm')  # unsigned
    ]
  end

  let(:base_query) do
    %Q(rpm -q --queryformat '%|DSAHEADER?{%{DSAHEADER:pgpsig}}:{%|RSAHEADER?{%{RSAHEADER:pgpsig}}:{%|SIGGPG?{%{SIGGPG:pgpsig}}:{%|SIGPGP?{%{SIGPGP:pgpsig}}:{(none)}|}|}|}|\\n')
  end

  describe '.load_key' do
    it 'loads a key when all metadata is found in files in the key dir' do
      result = Simp::Rpm::Signer.load_key(@key_dir)

      expect(result[:dir]).to eq @key_dir
      expect(result[:name]).to eq 'gatekeeper@simp.development.key'
      expect(result[:key_id]).to eq 'E5FED7D1'
      expect(result[:key_size]).to eq '4096R'
      expect(result[:password]).to eq 'LijQDE/oC8eF/2hw+N7lJ14Uhj6FBkzTaEEQVlx1JswJmfmAXbCH5rNB5oANNYU3CI6EuPFGEJ+gJiE6c1BePCREM5YmKbvPMUqpwuOemvbijQZz+m/u11Sk6oIlspaYMynVr1C/f1Ei2gYiSgLzeDdyPZGoaZZtB0r1aws6AN9Er3HvJd1LIkWi3Fl8Wdoy5dAGPIBfo/rrnOhFNh9P0cukWwgyqqEfPYi5Lrtl3881cFZkWo4P8DWmyr+AAz9gs3jXCh0C3TJK1Hn03l10wVu2pO8LR0bRhQX+9Hf6umTuTX0WaXB8XJ9pqeqSpBErwyJ9lmBiAnj4DrMbsVs/TFhK7mLnOl5MxCw1g5i50XASzL8+YbXsTgonYxc7u7DzLlvWbszDtNwBOSUnX1Au3iUhNdFB6hnQnCurA5flkdRcn9mRu1ZIjde02/M+dhSLaPF/IkFojs9vedbxX7+UKil2Y2sExXVQtclL0tbMKIUSLFDKwKzk/hJKp39jTsyLfzEaLosTXJZj7d7C3nBHBCI41EahEWLB7h54lilkGo3aTNPGIBDS/FFh50rU0YjczHUh1ivMqTQSyD98aFi4aGQNTtT5JI44ojcnd0ZE70TDOLoXgQSqbySK3gGZgvYqbE7ot1F5P5sAEdbF/ZfO4TPSTlE='
    end

    pending 'prompts user for metadata when some is missing from files in the key dir'

    it 'fails when gpg executable is not found' do
      Simp::Utils.expects(:which).with('gpg').returns(nil)
      expect{ Simp::Rpm::Signer.load_key(@key_dir) }.
        to raise_error(/ERROR: Cannot sign RPMs without 'gpg'/)
    end

    it 'fails when key dir cannot be found' do
      expect{ Simp::Rpm::Signer.load_key('/oops/dev') }.
        to raise_error(/ERROR: Could not find GPG keydir '\/oops\/dev'/)
    end
  end

  describe '.sign_rpm' do
    it 'signs the RPM with the given key' do
      # original RPM should not be signed
      result = `#{base_query} -p #{orig_rpms[0]} 2>/dev/null`
      expect(result).to_not match(/^RSA\/SHA1.* Key ID /)
      expect(result).to match(/none/)

      FileUtils.cp(orig_rpms[0], @tmp_dir)
      rpm = File.join(@tmp_dir, File.basename(orig_rpms[0]))

      Simp::Rpm::Signer.sign_rpm(rpm, @key_dir)

      # unsigned RPM should now be signed
      result = `#{base_query} -p #{rpm} 2>/dev/null`
      expect(result).to match(/^RSA\/SHA1.* Key ID #{@key_id}/)
      expect(result).to_not match(/none/)
    end

    it 'fails when gpgsign executable is not found' do
      Simp::Utils.expects(:which).with('rpmsign').returns(nil)
      expect{ Simp::Rpm::Signer.sign_rpm(orig_rpms[0], @key_dir) }.
        to raise_error(/ERROR: Cannot sign RPMs without 'rpmsign'/)
    end

    it 'logs failed signing and continues' do
      expect { Simp::Rpm::Signer.sign_rpm('/does/not/exist.rpm', @key_dir) }.
        to output(/Error occurred while attempting to sign/).to_stderr
    end
  end

  describe '.sign_rpms' do
    it 'signs all unsigned RPMs within a single directory with the given key' do
      rpm_dir = File.join(@tmp_dir, 'test1_rpms')
      FileUtils.mkdir(rpm_dir)
      FileUtils.cp(orig_rpms, rpm_dir)

      Simp::Rpm::Signer.sign_rpms(rpm_dir, @key_dir2)

      # unsigned RPM should now be signed with 'dev2'
      rpm = File.join(rpm_dir, File.basename(orig_rpms[0]))
      result = `#{base_query} -p #{rpm} 2>/dev/null`
      expect(result).to match(/^RSA\/SHA1.* Key ID #{@key_id2}/)

      rpm = File.join(rpm_dir, File.basename(orig_rpms[2]))
      result = `#{base_query} -p #{rpm} 2>/dev/null`
      expect(result).to match(/^RSA\/SHA1.* Key ID #{@key_id2}/)

      # RPM previously signed with 'dev' should have been left alone
      rpm = File.join(rpm_dir, File.basename(orig_rpms[1]))
      result = `#{base_query} -p #{rpm} 2>/dev/null`
      expect(result).to match(/^RSA\/SHA1.* Key ID #{@key_id}/)
    end

    it 'signs all RPMs within a multiple directories with the given key' do
      rpm_dirs = [
        File.join(@tmp_dir, 'test2_rpms1'),
        File.join(@tmp_dir, 'test2_rpms2')
      ]
      FileUtils.mkdir(rpm_dirs)
      rpm_dirs.each { |rpm_dir| FileUtils.cp(orig_rpms, rpm_dir) }

      Simp::Rpm::Signer.sign_rpms("#{@tmp_dir}/test2_rpms*", @key_dir2)

      rpm_dirs.each do |rpm_dir|
        # unsigned RPM should now be signed with 'dev2'
        rpm = File.join(rpm_dir, File.basename(orig_rpms[0]))
        result = `#{base_query} -p #{rpm} 2>/dev/null`
        expect(result).to match(/^RSA\/SHA1.* Key ID #{@key_id2}/)

        rpm = File.join(rpm_dir, File.basename(orig_rpms[2]))
        result = `#{base_query} -p #{rpm} 2>/dev/null`
        expect(result).to match(/^RSA\/SHA1.* Key ID #{@key_id2}/)

        # RPM previously signed with 'dev' should have been left alone
        rpm = File.join(rpm_dir, File.basename(orig_rpms[1]))
        result = `#{base_query} -p #{rpm} 2>/dev/null`
        expect(result).to match(/^RSA\/SHA1.* Key ID #{@key_id}/)
      end
    end

    it 'resigns signed RPMs when force=true' do
      rpm_dir = File.join(@tmp_dir, 'test3_rpms')
      FileUtils.mkdir(rpm_dir)
      FileUtils.cp(orig_rpms[2], rpm_dir)

      Simp::Rpm::Signer.sign_rpms(rpm_dir, @key_dir2, true)

      # RPM previously signed with 'dev' should now be signed with 'dev2'
      rpm = File.join(rpm_dir, File.basename(orig_rpms[2]))
      result = `#{base_query} -p #{rpm} 2>/dev/null`
      expect(result).to match(/^RSA\/SHA1.* Key ID #{@key_id2}/)
    end
  end

end
