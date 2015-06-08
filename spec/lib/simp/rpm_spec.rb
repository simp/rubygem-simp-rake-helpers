require 'simp/rpm'
require 'spec_helper'

describe Simp::RPM do
  before :all do
    dir        = File.expand_path( 'files', File.dirname( __FILE__ ) )
    @spec_file = File.join( dir, 'testpackage.spec' )
    @obj = Simp::RPM.new( @spec_file )
  end

  describe "#initialize" do
    it "initializes (smoke test)" do
      expect( @obj.class ).to eq Simp::RPM
    end
  end

  describe ".get_info" do
    it "extracts correct information from a .spec file" do
      info = Simp::RPM.get_info(@spec_file)
      expect( info.fetch( :name    ) ).to eq 'testpackage'
      expect( info.fetch( :version ) ).to eq '1'
    end
  end
end
