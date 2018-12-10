require 'simp/relchecks'
require 'spec_helper'

describe 'Simp::RelChecks.check_rpm_changelog' do
  let(:files_dir) {
    File.join( File.dirname(__FILE__), 'files', File.basename(__FILE__, '.rb'))
  }

  context 'with no project changelog errors' do
    it 'succeeds for a Puppet module' do
      component_dir = File.join(files_dir, 'module')

      expect{ Simp::RelChecks.check_rpm_changelog(component_dir) }.
        to_not raise_error
    end

    it 'succeeds for a non-Puppet asset' do
      component_dir = File.join(files_dir, 'asset')

      expect{ Simp::RelChecks.check_rpm_changelog(component_dir) }.
        to_not raise_error
    end
  end

  context 'with changelog errors' do
    it 'fails for a Puppet module' do
      component_dir = File.join(files_dir, 'module_with_misordered_entries')
      expect{ Simp::RelChecks.check_rpm_changelog(component_dir) }.
        to raise_error(/ERROR: Invalid changelog for module_with_misordered_entries/)
    end

    it 'fails for a non-Puppet asset' do
      component_dir = File.join(files_dir, 'asset_with_misordered_entries')

      expect{ Simp::RelChecks.check_rpm_changelog(component_dir) }.
        to raise_error(/ERROR: Invalid changelog for asset_with_misordered_entries/)
    end
  end
end
