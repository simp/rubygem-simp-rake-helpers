require 'simp/rake'
require 'spec_helper'

describe Simp::Rake do
  RSpec.configure do |c|
    c.include Simp::Rake
  end

  describe 'tests are missing' do
    it 'should have more tests' do
      skip 'TODO: write tests'
    end
  end
end
