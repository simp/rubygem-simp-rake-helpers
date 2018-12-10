require 'simp/rake/pupmod/helpers'
require 'spec_helper'

describe Simp::Rake::Pupmod::Helpers do
  before :each do
    fixtures_dir = File.expand_path( '../fixtures', __FILE__ )
    @simpmod = Simp::Rake::Pupmod::Helpers.new(File.join(fixtures_dir, 'simpmod'))
    @othermod = Simp::Rake::Pupmod::Helpers.new(File.join(fixtures_dir, 'othermod'))
  end

  describe '#initialize' do
    it 'initialized (smoke test)' do
      expect( @simpmod.class ).to eq Simp::Rake::Pupmod::Helpers
    end
  end

  describe '#metadata' do
    it 'reads a valid metadata.json (simp)' do
      expect( @simpmod.send( :metadata )['name'] ).to eq 'simp-simpmod'
      expect( @othermod.send( :metadata )['name'] ).to eq 'other-othermod'
    end
  end
end

