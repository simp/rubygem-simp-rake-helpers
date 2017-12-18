require 'simp/relchecks'
require 'spec_helper'

describe 'Simp::RelChecks.create_tag_changelog' do
  let(:files_dir) {
    File.join( File.dirname(__FILE__), 'files', File.basename(__FILE__, '.rb'))
  }

  describe '.create_tag_changelog' do
    context 'with valid module input' do
      it 'creates tag changelog from single changelog entry for latest version' do
        component_dir = File.join(files_dir, 'module_with_single_entry')
        module_changelog = Simp::RelChecks.create_tag_changelog(component_dir)
        expected = <<EOM

Release of 3.8.0

* Tue Jun 20 2017 Mary Jones <mary.jones@simp.com> - 3.8.0
  - Added a define, mod::instance
    - Creates standalone connections with their own configurations
      and services
    - Adds systemd support
  - Updated puppet requirement in metadata.json
EOM
        expect(module_changelog).to eq expected
      end

      it 'creates tag changelog from multiple changelog entries for latest version' do
        component_dir = File.join(files_dir, 'module_with_multiple_entries')
        module_changelog = Simp::RelChecks.create_tag_changelog(component_dir)
        expected = <<EOM

Release of 3.8.0

* Wed Nov 15 2017 Mary Jones <mary.jones@simp.com> - 3.8.0-0
  - Disable deprecation warnings by default

* Mon Nov 06 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0
  - Fixes split failure when "findmnt" does not exist on Linux
EOM
        expect(module_changelog).to eq expected
      end
    end

    context 'with invalid module input' do
      it 'fails when module info cannot be loaded' do
        component_dir = File.join(files_dir, 'module_without_changelog')
        expect{ Simp::RelChecks.create_tag_changelog(component_dir) }.to raise_error(
          /No CHANGELOG file found in .*module_without_changelog/)
      end

      it 'fails if no valid entry for the version can be found' do
        component_dir = File.join(files_dir, 'module_with_no_entry_for_version')
        expect{ Simp::RelChecks.create_tag_changelog(component_dir) }.to raise_error(
          /No valid changelog entry for version 4.0.0 found/)
      end

      it 'fails if entry with newer version than metadata.json is found' do
        component_dir = File.join(files_dir, 'module_with_newer_changelog_entry')
        expect{ Simp::RelChecks.create_tag_changelog(component_dir) }.to raise_error(
          /Changelog entry for version > 3.8.0 found:/)
      end

      it "fails if dates are out of order for the version's changelog entries" do
        component_dir = File.join(files_dir, 'module_with_misordered_entries')
        expect{ Simp::RelChecks.create_tag_changelog(component_dir) }.to raise_error(
          /ERROR:  Changelog entries are not properly date ordered/)
      end
    end

    context 'with valid asset input' do
      # since much of the changelog parsing code is shared between
      # module and asset changelog processing, here we will focus on
      # the parts of the code unique to asset changelog extraction
      it 'creates tag changelog from a changelog entry for latest version for a single-package spec file' do
        component_dir = File.join(files_dir, 'asset_with_single_package')
        asset_changelog = Simp::RelChecks.create_tag_changelog(component_dir)
        expected = <<EOM

Release of 1.0.0

* Wed Oct 18 2017 Jane Doe <jane.doe@simp.com> - 1.0.0-0
  - Single package
EOM
        expect(asset_changelog).to eq expected
      end

      it 'creates tag changelog from primary package changelog entries for latest version for a multi-package spec file' do
        component_dir = File.join(files_dir, 'asset_with_multiple_packages')
        asset_changelog = Simp::RelChecks.create_tag_changelog(component_dir)
        expected = <<EOM

Release of 4.0.3

* Thu Aug 31 2017 Jane Doe <jane.doe@simp.com> - 4.0.3
  - Fix bug Z
    - Thanks to Lilia Smith for the PR!

* Mon Jun 12 2017 Jane Doe <jane.doe@simp.com> - 4.0.3
  - Prompt user for new input
EOM
        expect(asset_changelog).to eq expected
      end

      it 'creates tag changelog from a changelog entry for latest version when release includes distribution' do
        component_dir = File.join(files_dir, 'asset_with_dist_in_release')
        asset_changelog = Simp::RelChecks.create_tag_changelog(component_dir)
        expected = <<EOM

Release of 1.0.0

* Wed Oct 18 2017 Jane Doe <jane.doe@simp.com> - 1.0.0-0
  - Package with distribution in release tag
EOM
        expect(asset_changelog).to eq expected
      end
    end

    context 'with invalid asset input' do

      it 'fails when asset info cannot be loaded' do
        component_dir = File.join(files_dir, 'asset_without_spec_file')
        expect{ Simp::RelChecks.create_tag_changelog(component_dir) }.to raise_error(
          /No RPM spec file found in .*asset_without_spec_file\/build/)
      end

      it 'fails when changelog is missing from asset RPM spec file' do
        #NOTE:  %changelog is optional in a spec file.  So this error
        #       is not found when the changelog is read from the spec
        #       file, but, instead, during post-validation
        component_dir = File.join(files_dir, 'asset_missing_changelog')
        expect{ Simp::RelChecks.create_tag_changelog(component_dir) }.to raise_error(
          /No valid changelog entry for version 1.0.0 found/)
      end

      it 'fails when release tag and release in changelog from asset RPM spec file are mismatched' do
        component_dir = File.join(files_dir, 'asset_mismatched_release')
        expect{ Simp::RelChecks.create_tag_changelog(component_dir) }.to raise_error(
          /Version release does not match/)
      end
    end
  end
end
