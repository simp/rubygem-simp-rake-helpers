require 'spec_helper'
describe 'othermod' do
  context 'with default values for all parameters' do
    it { should contain_class('othermod') }
  end
end
