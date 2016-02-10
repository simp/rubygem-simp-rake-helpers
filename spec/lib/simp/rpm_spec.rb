require 'simp/rpm'
require 'spec_helper'

describe Simp::RPM do
  before :all do
    dir          = File.expand_path( 'files', File.dirname( __FILE__ ) )
    @spec_file   = File.join( dir, 'testpackage.spec' )
    @spec_obj    = Simp::RPM.new( @spec_file )
    @m_spec_file = File.join( dir, 'testpackage-multi.spec' )
    @m_spec_obj  = Simp::RPM.new( @spec_file )
    @rpm_file    = File.join( dir, 'testpackage-1-0.noarch.rpm' )
    @rpm_obj     = Simp::RPM.new( @spec_file )
  end

  describe "#initialize" do

    it "initializes w/RPM (smoke test)" do
      expect( @rpm_obj.class ).to eq Simp::RPM
    end

    it "initializes w/spec file (smoke test)" do
      expect( @spec_obj.class ).to eq Simp::RPM
    end

    it "initializes w/multi-package spec file (smoke test)" do
      expect( @m_spec_obj.class ).to eq Simp::RPM
    end

  end

  describe ".get_info" do
    it "extracts correct information from a .spec file" do
      info = Simp::RPM.get_info(@spec_file)
      expect( info.fetch( :name    ) ).to eq 'testpackage'
      expect( info.fetch( :version ) ).to eq '1'
    end

    it "extracts correct information from an .rpm file" do
      info = Simp::RPM.get_info(@rpm_file)
      expect( info.fetch( :name    ) ).to eq 'testpackage'
      expect( info.fetch( :version ) ).to eq '1'
    end

    it "extracts coreect information from the first entry from a multi-package .spec file" do
      info = Simp::RPM.get_info(@m_spec_file)
      expect( info.fetch( :name    ) ).to eq 'testpackage-multi-1'
      expect( info.fetch( :version ) ).to eq '1'
    end
  end
end
