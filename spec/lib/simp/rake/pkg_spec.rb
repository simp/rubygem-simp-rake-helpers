require 'simp/rake/pkg'
require 'spec_helper'

describe Simp::Rake::Pkg do
  before :all do
    dir        = File.expand_path( '../files', File.dirname( __FILE__ ) )
    @obj = Simp::Rake::Pkg.new( dir )
  end

  describe "#initialize" do
    it "initializes (smoke test)" do
      expect( @obj.class ).to eq Simp::Rake::Pkg

          require 'pry'; binding.pry
    end
  end
end
