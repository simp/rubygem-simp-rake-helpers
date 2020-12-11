require 'simp/rake'
require 'spec_helper'

describe Simp::Rake do
  RSpec.configure do |c|
    c.include Simp::Rake
  end

  describe ".get_cpu_limit" do
    it "detects number of CPUs" do
      expect(Parallel).to receive(:processor_count).and_return(3)
      expect( get_cpu_limit ).to eq 2
    end
  end


  describe 'tests are missing' do
    it 'should have more tests' do
      skip 'TODO: write more tests'
    end
  end
end
