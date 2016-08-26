require 'simp/rake/build/helpers'
require 'spec_helper'

describe Simp::Rake::Build::Helpers do
  before :each do
    dir        = File.expand_path( '../../files/simp_build', File.dirname( __FILE__ ) )
    @obj = Simp::Rake::Build::Helpers.new( dir )
  end

  describe "#initialize" do
    it "initialized (smoke test)" do
      expect( @obj.class ).to eq Simp::Rake::Build::Helpers
    end
  end
end


