require 'simp/rake/pupmod/helpers'
require 'spec_helper'

describe Simp::Rake::Pupmod::Helpers do
  before :each do
    @obj = Simp::Rake::Pupmod::Helpers.new( File.dirname(__FILE__) )
  end

  describe "#initialize" do
    it "initialized (smoke test)" do
      expect( @obj.class ).to eq Simp::Rake::Pupmod::Helpers
    end
  end
end

