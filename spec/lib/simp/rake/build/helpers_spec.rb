require 'simp/rake/build/helpers'
require 'spec_helper'

describe Simp::Rake::Build::Helpers do
  before :each do
    dir        = File.expand_path( '../../files/simp_build', File.dirname( __FILE__ ) )
    env = ENV['SIMP_RPM_dist'].dup
    ENV['SIMP_RPM_dist'] = '.el7'
    @obj = Simp::Rake::Build::Helpers.new( dir )
    ENV['SIMP_RPM_dist'] = env
  end

  describe "#initialize" do
    it "initialized (smoke test)" do
      expect( @obj.class ).to eq Simp::Rake::Build::Helpers
    end
  end
end


