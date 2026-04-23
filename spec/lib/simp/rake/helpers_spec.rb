# frozen_string_literal: true

require 'simp/rake/helpers'
require 'spec_helper'

describe Simp::Rake::Helpers do
  before :each do
    @obj = described_class.new
  end

  describe '#initialize' do
    it 'initialized (smoke test)' do
      expect(@obj.class).to eq described_class
    end
  end
end
