# frozen_string_literal: true

require 'spec_helper'
describe 'othermod' do
  context 'with default values for all parameters' do
    it { is_expected.to contain_class('othermod') }
  end
end
