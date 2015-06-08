require 'simp/rake/helpers'
require 'spec_helper'

describe Simp::Rake::Helpers do
  before :each do
    @obj = Simp::Rake::Helpers.new
  end

  describe "#initialize" do
    it "initialized (smoke test)" do
      expect( @obj.class ).to eq Simp::Rake::Helpers
    end
  end
end

