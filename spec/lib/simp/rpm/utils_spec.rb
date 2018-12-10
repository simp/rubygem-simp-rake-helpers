require 'simp/rpm/utils'
require 'spec_helper'

describe Simp::Rpm::Utils do

  let(:files_dir) { files_dir = File.expand_path('files', File.dirname( __FILE__ )) }

=begin
  describe '.create_rpm_build_metadata' do
  end

=end

  describe '.get_rpm_arch' do
    it 'returns the arch when the RPM name contains a known arch' do
      expect( Simp::Rpm::Utils.get_rpm_arch('testpackage-0.0.1-0.noarch.rpm') ).
        to eq 'noarch'

      expect( Simp::Rpm::Utils.get_rpm_arch('testpackage-0.0.1-0.x86_64.rpm') ).
        to eq 'x86_64'
    end

    it 'returns the arch when the RPM name contains the arch in a custom arch_list' do
      custom = ['myarch1', 'myarch2']
      expect( Simp::Rpm::Utils.get_rpm_arch('testpackage-0.0.1-0.myarch1.rpm', custom) ).
        to eq 'myarch1'

      expect( Simp::Rpm::Utils.get_rpm_arch('testpackage-0.0.1-0.myarch2.rpm', custom) ).
        to eq 'myarch2'
    end

    it 'returns the arch extracted from the RPM when missing from the RPM name' do
      rpm = File.join(files_dir, 'pupmod-simp-beakertest-0.0.1-0.rpm')
      expect( Simp::Rpm::Utils.get_rpm_arch(rpm) ).to eq 'noarch'
    end
  end

end
