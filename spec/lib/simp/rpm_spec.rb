# frozen_string_literal: true

require 'simp/rpm'
require 'spec_helper'

describe Simp::RPM do
  before :all do
    dir          = File.expand_path('files', File.dirname(__FILE__))
    @spec_file   = File.join(dir, 'testpackage.spec')
    @spec_obj    = described_class.new(@spec_file)

    @m_spec_file = File.join(dir, 'testpackage-multi.spec')
    @m_spec_obj  = described_class.new(@m_spec_file)

    @rpm_file    = File.join(dir, 'testpackage-1-0.noarch.rpm')
    @rpm_obj     = described_class.new(@rpm_file)

    @d_spec_file = File.join(dir, 'testpackage-dist.spec')
    @d_spec_obj  = described_class.new(@d_spec_file)

    @d_rpm_file    = File.join(dir, 'testpackage-1-0.el7.noarch.rpm')
    @d_rpm_obj     = described_class.new(@d_rpm_file)

    @rc0_spec_file = File.join(dir, 'testpackage-rc0.spec')
    @rc0_spec_obj  = described_class.new(@rc0_spec_file)

    # FIXME
    #    @signed_rpm_file = File.join( dir, 'testpackage-1-0.noarch.rpm' )
    #    @signed_rpm_obj  = Simp::RPM.new( @signed_rpm_file )
  end

  describe 'class #initialize' do
    it 'initializes w/unsigned RPM (smoke test)' do
      expect(@rpm_obj.class).to eq described_class
    end

    # FIXME
    #    it 'initializes w/signed RPM (smoke test)' do
    #      expect( @signed_rpm_obj.class ).to eq Simp::RPM
    #    end

    it 'initializes w/spec file (smoke test)' do
      expect(@spec_obj.class).to eq described_class
    end

    it 'initializes w/multi-package spec file (smoke test)' do
      expect(@m_spec_obj.class).to eq described_class
    end

    it 'fails to initialize when rpm source cannot be opened' do
      expect { described_class.new('/does/not/exist/') }.to raise_error(RuntimeError)
    end
  end

  describe 'getter methods' do
    describe '#packages' do
      it 'returns packages' do
        expect(@rpm_obj.packages).to eq ['testpackage']
        #        expect( @signed_rpm_obj.packages ).to eq ['testpackage']
        expect(@spec_obj.packages).to eq ['testpackage']
        expect(@m_spec_obj.packages).to eq ['testpackage', 'testpackage-doc']
      end
    end

    describe '#basename' do
      it 'returns basename' do
        expect(@rpm_obj.basename).to eq 'testpackage'
        #        expect( @signed_rpm_obj.basename ).to eq 'testpackage'
        expect(@spec_obj.basename).to eq 'testpackage'
        expect(@m_spec_obj.basename).to eq 'testpackage'
        expect(@m_spec_obj.basename('testpackage')).to eq 'testpackage'
        expect(@m_spec_obj.basename('testpackage-doc')).to eq 'testpackage-doc'
      end

      it 'fails when invalid package specified' do
        expect { @rpm_obj.basename('oops') }.to raise_error(ArgumentError)
        #        expect { @signed_rpm_obj.basename('oops') }.to raise_error(ArgumentError)
        expect { @spec_obj.basename('oops') }.to raise_error(ArgumentError)
        expect { @m_spec_obj.basename('oops') }.to raise_error(ArgumentError)
      end
    end

    describe '#version' do
      it 'returns version' do
        expect(@rpm_obj.version).to eq '1'
        #        expect( @signed_rpm_obj.version ).to eq '1'
        expect(@spec_obj.version).to eq '1'
        expect(@m_spec_obj.version).to eq '1'
        expect(@m_spec_obj.version('testpackage')).to eq '1'
        expect(@m_spec_obj.version('testpackage-doc')).to eq '1.0.1'
        expect(@rc0_spec_obj.version).to eq '1.0.0'
      end

      it 'fails when invalid package specified' do
        expect { @rpm_obj.version('oops') }.to raise_error(ArgumentError)
        #        expect { @signed_rpm_obj.version('oops') }.to raise_error(ArgumentError)
        expect { @spec_obj.version('oops') }.to raise_error(ArgumentError)
        expect { @m_spec_obj.version('oops') }.to raise_error(ArgumentError)
      end
    end

    describe '#release' do
      it 'returns release' do
        expect(@rpm_obj.release).to eq '0'
        #        expect( @signed_rpm_obj.release ).to eq '0'
        expect(@spec_obj.release).to eq '0'
        expect(@m_spec_obj.release).to eq '0'
        expect(@m_spec_obj.release('testpackage')).to eq '0'
        expect(@m_spec_obj.release('testpackage-doc')).to eq '2'
        expect(@rc0_spec_obj.release).to eq 'rc0'
      end

      it 'fails when invalid package specified' do
        expect { @rpm_obj.release('oops') }.to raise_error(ArgumentError)
        #        expect { @signed_rpm_obj.release('oops') }.to raise_error(ArgumentError)
        expect { @spec_obj.release('oops') }.to raise_error(ArgumentError)
        expect { @m_spec_obj.release('oops') }.to raise_error(ArgumentError)
      end
    end

    describe '#full_version' do
      it 'returns full_version' do
        expect(@rpm_obj.full_version).to eq '1-0'
        #        expect( @signed_rpm_obj.full_version ).to eq '1-0'
        expect(@spec_obj.full_version).to eq '1-0'
        expect(@m_spec_obj.full_version).to eq '1-0'
        expect(@m_spec_obj.full_version('testpackage')).to eq '1-0'
        expect(@m_spec_obj.full_version('testpackage-doc')).to eq '1.0.1-2'
      end

      it 'fails when invalid package specified' do
        expect { @rpm_obj.full_version('oops') }.to raise_error(ArgumentError)
        #        expect { @signed_rpm_obj.full_version('oops') }.to raise_error(ArgumentError)
        expect { @spec_obj.full_version('oops') }.to raise_error(ArgumentError)
        expect { @m_spec_obj.full_version('oops') }.to raise_error(ArgumentError)
      end
    end

    describe '#name' do
      it 'returns name' do
        expect(@rpm_obj.name).to eq 'testpackage-1-0'
        #        expect( @signed_rpm_obj.name ).to eq 'testpackage-1-0'
        expect(@spec_obj.name).to eq 'testpackage-1-0'
        expect(@m_spec_obj.name).to eq 'testpackage-1-0'
        expect(@m_spec_obj.name('testpackage')).to eq 'testpackage-1-0'
        expect(@m_spec_obj.name('testpackage-doc')).to eq 'testpackage-doc-1.0.1-2'
      end

      it 'fails when invalid package specified' do
        expect { @rpm_obj.name('oops') }.to raise_error(ArgumentError)
        #        expect { @signed_rpm_obj.name('oops') }.to raise_error(ArgumentError)
        expect { @spec_obj.name('oops') }.to raise_error(ArgumentError)
        expect { @m_spec_obj.name('oops') }.to raise_error(ArgumentError)
      end
    end

    describe '#arch' do
      it 'returns arch' do
        expect(@rpm_obj.arch).to eq 'noarch'
        #        expect( @signed_rpm_obj.arch ).to eq 'noarch'
        expect(@spec_obj.arch).to eq 'noarch'
        expect(@m_spec_obj.arch).to eq 'noarch'
        expect(@m_spec_obj.arch('testpackage')).to eq 'noarch'
        expect(@m_spec_obj.arch('testpackage-doc')).to eq 'noarch'
      end

      it 'fails when invalid package specified' do
        expect { @rpm_obj.arch('oops') }.to raise_error(ArgumentError)
        #        expect { @signed_rpm_obj.arch('oops') }.to raise_error(ArgumentError)
        expect { @spec_obj.arch('oops') }.to raise_error(ArgumentError)
        expect { @m_spec_obj.arch('oops') }.to raise_error(ArgumentError)
      end
    end

    describe '#signature' do
      it 'returns signature' do
        expect(@rpm_obj.signature).to be_nil
        #        expect( @signed_rpm_obj.signature ).to eq 'xxxx'
        expect(@spec_obj.signature).to be_nil
        expect(@m_spec_obj.signature).to be_nil
        expect(@m_spec_obj.signature('testpackage')).to be_nil
        expect(@m_spec_obj.signature('testpackage-doc')).to be_nil
      end

      it 'fails when invalid package specified' do
        expect { @rpm_obj.signature('oops') }.to raise_error(ArgumentError)
        #        expect { @signed_rpm_obj.signature('oops') }.to raise_error(ArgumentError)
        expect { @spec_obj.signature('oops') }.to raise_error(ArgumentError)
        expect { @m_spec_obj.signature('oops') }.to raise_error(ArgumentError)
      end
    end

    describe '#rpm_name' do
      it 'returns rpm_name' do
        expect(@rpm_obj.rpm_name).to eq 'testpackage-1-0.noarch.rpm'
        #        expect( @signed_rpm_obj.rpm_name ).to eq 'testpackage-1-0.noarch.rpm'
        expect(@spec_obj.rpm_name).to eq 'testpackage-1-0.noarch.rpm'
        expect(@m_spec_obj.rpm_name).to eq 'testpackage-1-0.noarch.rpm'
        expect(@m_spec_obj.rpm_name('testpackage')).to eq 'testpackage-1-0.noarch.rpm'
        expect(@m_spec_obj.rpm_name('testpackage-doc')).to eq 'testpackage-doc-1.0.1-2.noarch.rpm'
      end

      it 'fails when invalid package specified' do
        expect { @rpm_obj.rpm_name('oops') }.to raise_error(ArgumentError)
        #        expect { @signed_rpm_obj.rpm_name('oops') }.to raise_error(ArgumentError)
        expect { @spec_obj.rpm_name('oops') }.to raise_error(ArgumentError)
        expect { @m_spec_obj.rpm_name('oops') }.to raise_error(ArgumentError)
      end
    end

    describe '#has_dist_tag?' do
      it 'returns has_dist_tag?' do
        expect(@rpm_obj.has_dist_tag?).to be false
        #        expect( @signed_rpm_obj.has_dist_tag?).to eq false
        expect(@d_rpm_obj.has_dist_tag?).to be true
        expect(@spec_obj.has_dist_tag?).to be false
        expect(@d_spec_obj.has_dist_tag?).to be true
      end

      it 'fails when invalid package specified' do
        expect { @rpm_obj.has_dist_tag?('oops') }.to raise_error(ArgumentError)
        #        expect { @signed_rpm_obj.has_dist_tag?('oops') }.to raise_error(ArgumentError)
        expect { @d_rpm_obj.has_dist_tag?('oops') }.to raise_error(ArgumentError)
        expect { @spec_obj.has_dist_tag?('oops') }.to raise_error(ArgumentError)
        expect { @m_spec_obj.has_dist_tag?('oops') }.to raise_error(ArgumentError)
        expect { @d_spec_obj.has_dist_tag?('oops') }.to raise_error(ArgumentError)
      end
    end

    describe '#dist' do
      before :each do
        @pre_env = ENV.fetch('SIMP_RPM_dist', nil)
        ENV['SIMP_RPM_dist'] = nil
      end

      after :each do
        ENV['SIMP_RPM_dist'] = @pre_env
      end

      it 'returns dist' do
        allow(described_class).to receive(:system_dist).and_return('.testdist')
        rpm_obj    = described_class.new(@rpm_file)
        d_rpm_obj  = described_class.new(@d_rpm_file)
        spec_obj   = described_class.new(@spec_file)
        d_spec_obj = described_class.new(@d_spec_file)

        expect(rpm_obj.dist).to eq '.testdist'
        expect(d_rpm_obj.dist).to eq '.el7'
        expect(spec_obj.dist).to eq '.testdist'
        expect(d_spec_obj.dist).to eq '.testdist'
      end

      context 'when ENV[SIMP_RPM_dist] is set' do
        before :each do
          @_pre_env = ENV.fetch('SIMP_RPM_dist', nil)
          ENV['SIMP_RPM_dist'] = 'foo'
        end

        after :each do
          ENV['SIMP_RPM_dist'] = @_pre_env
        end

        it 'returns target dist for spec files when SIMP_RPM_dist is set' do
          rpm_obj    = described_class.new(@rpm_file)
          spec_obj   = described_class.new(@spec_file)
          d_spec_obj = described_class.new(@d_spec_file)
          described_class.new(@m_spec_file)
          d_rpm_obj = described_class.new(@d_rpm_file)

          expect(rpm_obj.has_dist_tag?).to be false
          expect(spec_obj.has_dist_tag?).to be false
          expect(d_rpm_obj.has_dist_tag?).to be true
          expect(d_spec_obj.has_dist_tag?).to be true

          expect(d_spec_obj.dist).to eq '.foo'
          expect(d_spec_obj.full_version).to match(%r{\.foo$})
          expect(d_spec_obj.name).to match(%r{\.foo$})
          expect(d_spec_obj.release).to match(%r{\.foo$})

          # The RPMs are already created as .el7; no env vars or hinting
          # should affect them
          expect(d_rpm_obj.dist).to eq '.el7'
        end
      end

      it 'fails when invalid package specified' do
        expect { @rpm_obj.dist('oops') }.to raise_error(ArgumentError)
        #        expect { @signed_rpm_obj.dist('oops') }.to raise_error(ArgumentError)
        expect { @d_rpm_obj.dist('oops') }.to raise_error(ArgumentError)
        expect { @spec_obj.dist('oops') }.to raise_error(ArgumentError)
        expect { @m_spec_obj.dist('oops') }.to raise_error(ArgumentError)
        expect { @d_spec_obj.dist('oops') }.to raise_error(ArgumentError)
      end
    end
  end

  #   describe '#newer? and #package_newer?' do
  #   end
  #
  #   describe '#valid_package?' do
  #   end
  #
  #   describe '.copy_wo_vcs?' do
  #   end
  #
  #   describe '.execute?' do
  #   end

  describe '.get_info' do
    it 'extracts correct information from a .spec file' do
      info = described_class.get_info(@spec_file)
      expect(info.fetch(:basename)).to eq 'testpackage'
      expect(info.fetch(:version)).to eq '1'
      expect(info.fetch(:release)).to eq '0'
      expect(info.fetch(:full_version)).to eq '1-0'
      expect(info.fetch(:name)).to eq 'testpackage-1-0'
      expect(info.fetch(:arch)).to eq 'noarch'
      expect(info[:signature]).to be_nil
      expect(info.fetch(:rpm_name)).to eq 'testpackage-1-0.noarch.rpm'
    end

    it 'extracts correct information from an .rpm file' do
      info = described_class.get_info(@rpm_file)
      expect(info.fetch(:basename)).to eq 'testpackage'
      expect(info.fetch(:version)).to eq '1'
      expect(info.fetch(:release)).to eq '0'
      expect(info.fetch(:full_version)).to eq '1-0'
      expect(info.fetch(:name)).to eq 'testpackage-1-0'
      expect(info.fetch(:arch)).to eq 'noarch'
      expect(info[:signature]).to be_nil
      expect(info.fetch(:rpm_name)).to eq 'testpackage-1-0.noarch.rpm'
    end

    it 'extracts correct information for all entries from a multi-package .spec file' do
      info = described_class.get_info(@m_spec_file)
      expect(info.size).to eq 2
      expect(info[0].fetch(:basename)).to eq 'testpackage'
      expect(info[0].fetch(:version)).to eq '1'
      expect(info[0].fetch(:release)).to eq '0'
      expect(info[0].fetch(:full_version)).to eq '1-0'
      expect(info[0].fetch(:name)).to eq 'testpackage-1-0'
      expect(info[0].fetch(:arch)).to eq 'noarch'
      expect(info[0][:signature]).to be_nil
      expect(info[0].fetch(:rpm_name)).to eq 'testpackage-1-0.noarch.rpm'

      expect(info[1].fetch(:basename)).to eq 'testpackage-doc'
      expect(info[1].fetch(:version)).to eq '1.0.1'
      expect(info[1].fetch(:release)).to eq '2'
      expect(info[1].fetch(:full_version)).to eq '1.0.1-2'
      expect(info[1].fetch(:name)).to eq 'testpackage-doc-1.0.1-2'
      expect(info[1].fetch(:arch)).to eq 'noarch'
      expect(info[1][:signature]).to be_nil
      expect(info[1].fetch(:rpm_name)).to eq 'testpackage-doc-1.0.1-2.noarch.rpm'
    end

    it 'fails to when rpm source cannot be opened' do
      expect { described_class.get_info('/does/not/exist/') }.to raise_error(RuntimeError)
    end
  end

  #   describe '.indent' do
  #   end
  #
  #   describe '.create_rpm_build_metadata' do
  #   end
end
