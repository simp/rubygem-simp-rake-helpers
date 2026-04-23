# frozen_string_literal: true

require 'simp/rake/pkg'
require 'spec_helper'

describe Simp::Rake::Pkg do
  before :all do
    dir = File.expand_path('../files', File.dirname(__FILE__))
    @obj = described_class.new(dir)
  end

  describe '#initialize' do
    it 'initializes (smoke test)' do
      expect(@obj.class).to eq described_class
    end
  end
end
