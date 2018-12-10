require 'simp/utils'
require 'spec_helper'

describe Simp::Utils do
=begin
  describe '.clean_yaml' do
  end

  describe '.copy_wo_vcs' do
  end

  describe '.encode_line' do
  end

  describe '.execute' do
  end
=end

  describe '.get_cpu_limit' do
    it 'detects number of CPUs' do
      expect( Simp::Utils.get_cpu_limit ).to be > 0
    end

    it 'uses 1 CPU when 0 requested' do
      expect( Simp::Utils.get_cpu_limit(0) ).to eq 1
    end
  end

=begin
  describe '.indent' do
  end

  describe '.which' do
  end
=end

end
