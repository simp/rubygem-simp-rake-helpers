# frozen_string_literal: true

require 'simp/relchecks'
require 'spec_helper'

describe 'Simp::RelChecks.check_rpm_changelog' do
  let(:files_dir) do
    File.join(File.dirname(__FILE__), 'files', File.basename(__FILE__, '.rb'))
  end

  let(:templates_dir) do
    File.join(File.dirname(__FILE__), '..', '..', '..', 'lib', 'simp', 'rake',
              'helpers', 'assets', 'rpm_spec')
  end

  context 'with no project changelog errors' do
    it 'succeeds for a Puppet module' do
      component_dir = File.join(files_dir, 'module')
      component_spec = File.join(templates_dir, 'simpdefault.spec')

      expect { Simp::RelChecks.check_rpm_changelog(component_dir, component_spec) }
        .not_to raise_error
    end

    it 'succeeds for a non-Puppet asset' do
      component_dir = File.join(files_dir, 'asset')
      component_spec = File.join(component_dir, 'build', 'asset.spec')

      expect { Simp::RelChecks.check_rpm_changelog(component_dir, component_spec) }
        .not_to raise_error
    end
  end

  context 'with changelog errors' do
    # rpm >= 4.16 (EL9+) reports misordered changelog entries on stderr but
    # exits 0; check_rpm_changelog detects the reported message, so these are
    # expected to fail on every supported rpm version.
    it 'fails for a Puppet module' do
      component_dir = File.join(files_dir, 'module_with_misordered_entries')
      component_spec = File.join(templates_dir, 'simpdefault.spec')

      expect { Simp::RelChecks.check_rpm_changelog(component_dir, component_spec) }
        .to raise_error(%r{ERROR: Invalid changelog for module_with_misordered_entries})
    end

    it 'fails for a non-Puppet asset' do
      component_dir = File.join(files_dir, 'asset_with_misordered_entries')
      component_spec = File.join(component_dir, 'build', 'asset_with_misordered_entries.spec')

      expect { Simp::RelChecks.check_rpm_changelog(component_dir, component_spec) }
        .to raise_error(%r{ERROR: Invalid changelog for asset_with_misordered_entries})
    end
  end
end
