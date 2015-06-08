require 'simp/rake'
require 'spec_helper'

describe Simp::Rake do
  RSpec.configure do |c|
    c.include Simp::Rake
  end

  describe ".get_cpu_limit" do
    it "detects number of CPUs" do
      expect( get_cpu_limit ).to be > 0
    end
  end


  describe 'tests are missing' do
    it 'should have more tests' do
      skip 'TODO: write more tests'
    end
  end
end
