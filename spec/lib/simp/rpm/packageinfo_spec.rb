require 'simp/rpm/packageinfo'
require 'spec_helper'

describe Simp::Rpm::PackageInfo do
  before :all do
    files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )
    @unsigned_rpm = File.join(files_dir, 'pupmod-simp-beakertest-0.0.1-0.noarch.rpm')
    @pinfo = Simp::Rpm::PackageInfo.new(@unsigned_rpm)

    @signed_rpm = File.join(files_dir, 'pupmod-simp-beakertest-0.0.2-0.noarch.rpm')
    @pinfo_with_sig = Simp::Rpm::PackageInfo.new(@signed_rpm)
  end

  describe 'class #initialize' do

    it 'fails to initialize when RPM file cannot be opened' do
      expect{ Simp::Rpm::PackageInfo.new('/does/not/exist/') }.to raise_error(ArgumentError)
    end
  end

  describe 'getter methods' do

    context '#arch' do
      it 'returns the package arch' do
        expect( @pinfo.arch ).to eq 'noarch'
        expect( @pinfo_with_sig.arch ).to eq 'noarch'
      end
    end

    context '#basename' do
      it 'returns the package basename' do
        expect( @pinfo.basename ).to eq 'pupmod-simp-beakertest'
        expect( @pinfo_with_sig.basename ).to eq 'pupmod-simp-beakertest'
      end
    end

    context '#full_version' do
      it 'returns package full version' do
        expect( @pinfo.full_version ).to eq '0.0.1-0'
        expect( @pinfo_with_sig.full_version ).to eq '0.0.2-0'
      end
    end

    context '#info' do
      it 'extracts correct information from an unsigned .rpm file' do
        info = @pinfo.info
        expect( info.fetch( :basename ) ).to eq 'pupmod-simp-beakertest'
        expect( info.fetch( :version ) ).to eq '0.0.1'
        expect( info.fetch( :release ) ).to eq '0'
        expect( info.fetch( :full_version ) ).to eq '0.0.1-0'
        expect( info.fetch( :name ) ).to eq 'pupmod-simp-beakertest-0.0.1-0'
        expect( info.fetch( :arch ) ).to eq 'noarch'
        expect( info.fetch( :signature ) ).to be_nil
        expect( info.fetch( :rpm_name ) ).to eq 'pupmod-simp-beakertest-0.0.1-0.noarch.rpm'
      end

      it 'extracts correct information from a signed .rpm file' do
        info = @pinfo_with_sig.info
        expect( info.fetch( :basename ) ).to eq 'pupmod-simp-beakertest'
        expect( info.fetch( :version ) ).to eq '0.0.2'
        expect( info.fetch( :release ) ).to eq '0'
        expect( info.fetch( :full_version ) ).to eq '0.0.2-0'
        expect( info.fetch( :name ) ).to eq 'pupmod-simp-beakertest-0.0.2-0'
        expect( info.fetch( :arch ) ).to eq 'noarch'
        expect( info.fetch( :signature ) ).to match /RSA\/SHA1, .*, Key ID 91c40758e5fed7d1/
        expect( info.fetch( :rpm_name ) ).to eq 'pupmod-simp-beakertest-0.0.2-0.noarch.rpm'
      end
    end

    context '#name' do
      it 'returns the full package name' do
        expect( @pinfo.name ).to eq 'pupmod-simp-beakertest-0.0.1-0'
        expect( @pinfo_with_sig.name ).to eq 'pupmod-simp-beakertest-0.0.2-0'
      end
    end

    context '#release' do
      it 'returns the package release' do
        expect( @pinfo.release ).to eq '0'
        expect( @pinfo_with_sig.release ).to eq '0'
      end
    end

    context '#rpm_name' do
      it 'returns the RPM name' do
        expect( @pinfo.rpm_name ).to eq 'pupmod-simp-beakertest-0.0.1-0.noarch.rpm'
        expect( @pinfo_with_sig.rpm_name ).to eq 'pupmod-simp-beakertest-0.0.2-0.noarch.rpm'
      end
    end

    context '#signature' do
      it 'returns the RPM signature' do
        expect( @pinfo.signature ).to be nil
        expect( @pinfo_with_sig.signature ).to match /RSA\/SHA1, .*, Key ID 91c40758e5fed7d1/
      end
    end

    context '#version' do
      it 'returns the package version' do
        expect( @pinfo.version ).to eq '0.0.1'
        expect( @pinfo_with_sig.version ).to eq '0.0.2'
      end
    end


    context 'RPM query failures' do
      it 'fails when RPM basic info query fails' do
        failed_result = {
          :exit_status => 1,
          :stdout      => '',
          :stderr      => 'RPM basic query failed'
        }
        Simp::Utils.expects(:execute).returns(failed_result)
        pinfo = Simp::Rpm::PackageInfo.new(@unsigned_rpm)
        expect { pinfo.arch }.to raise_error(/RPM basic query failed/)
      end

      it 'fails when RPM signature query fails' do
        failed_result = {
          :exit_status => 1,
          :stdout      => '',
          :stderr      => 'RPM signature query failed'
        }
        Simp::Utils.expects(:execute).returns(failed_result)
        pinfo = Simp::Rpm::PackageInfo.new(@unsigned_rpm)
        expect { pinfo.signature }.to raise_error(/RPM signature query failed/)
      end
    end

  end

  describe '#newer?' do
    it 'returns true with other_rpm is nil' do
      expect( @pinfo.newer?(nil) ).to be true
    end

    it 'returns true with other_rpm is empty' do
      expect( @pinfo.newer?('') ).to be true
    end

    it 'returns false when other_rpm has a newer version' do
      expect( @pinfo.newer?(@signed_rpm) ).to be false
    end

    it 'returns false when other_rpm has the same version and release' do
      expect( @pinfo.newer?(@unsigned_rpm) ).to be false
    end

    it 'returns false when other_rpm has the same version but a newer release' do
      expect( @pinfo.newer?('pupmod-simp-beakertest-0.0.1-1.noarch.rpm') ).to be false
    end

    it 'returns true when other_rpm has an older version' do
      expect( @pinfo_with_sig.newer?(@unsigned_rpm) ).to be true
    end

    #FIXME generate an RPM for this comparison
    xit 'returns true when other_rpm has the same version but an older release'

    it 'fails when other_rpm does not end with .rpm' do
      expect{ @pinfo.newer?('pupmod-simp-beakertest-0.0.1-1') }.to raise_error(ArgumentError)
    end

    it "fails if Gem::Version cannot be constructed from other_rpm's full_version" do
      expect{ @pinfo.newer?('pupmod-simp-beakertest-x.0.3-0.noarch.rpm') }.
        to raise_error(/could not compare RPMs/)


    end
  end

end
