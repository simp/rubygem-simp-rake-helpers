require 'simp/relchecks'
require 'spec_helper'

describe 'Simp::RelChecks.check_rpm_changelog' do
  let(:files_dir) {
    File.join( File.dirname(__FILE__), 'files', File.basename(__FILE__, '.rb'))
  }

  let(:templates_dir) {
    File.join( File.dirname(__FILE__), '..', '..', '..', 'lib', 'simp', 'rake',
      'helpers', 'assets', 'rpm_spec' )
  }

  context 'with no project changelog errors' do
    it 'succeeds for a Puppet module' do
      component_dir = File.join(files_dir, 'module')
      component_spec = File.join(templates_dir, 'simpdefault.spec')

      expect{ Simp::RelChecks.check_rpm_changelog(component_dir, component_spec) }.
        to_not raise_error
    end

    it 'succeeds for a non-Puppet asset' do
      component_dir = File.join(files_dir, 'asset')
      component_spec = File.join(component_dir, 'build', 'asset.spec')

      expect{ Simp::RelChecks.check_rpm_changelog(component_dir, component_spec) }.
        to_not raise_error
    end
  end

  context 'with changelog errors' do
    it 'fails for a Puppet module' do
      component_dir = File.join(files_dir, 'module_with_misordered_entries')
      component_spec = File.join(templates_dir, 'simpdefault.spec')

      expect{ Simp::RelChecks.check_rpm_changelog(component_dir, component_spec) }.
        to raise_error(/ERROR: Invalid changelog for module_with_misordered_entries/)
    end

    it 'fails for a non-Puppet asset' do
      component_dir = File.join(files_dir, 'asset_with_misordered_entries')
      component_spec = File.join(component_dir, 'build', 'asset_with_misordered_entries.spec')

      expect{ Simp::RelChecks.check_rpm_changelog(component_dir, component_spec) }.
        to raise_error(/ERROR: Invalid changelog for asset_with_misordered_entries/)
    end
  end
end
