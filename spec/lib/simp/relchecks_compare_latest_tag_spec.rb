require 'simp/relchecks'
require 'spec_helper'

describe 'Simp::RelChecks.compare_latest_tag' do
  let(:files_dir) {
    File.join( File.dirname(__FILE__), 'files', File.basename(__FILE__, '.rb'))
  }

  let(:component_dir) {  File.join(files_dir, 'module') }

  context 'with no project errors' do
    it 'reports no tags for a project with no tags' do
      Simp::RelChecks.expects(:`).with('git fetch -t origin 2>/dev/null').returns("\n")
      Simp::RelChecks.expects(:`).with('git tag -l').returns("\n")

      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to output("  No tags exist from origin\n").to_stdout
    end

    it 'reports no new tag required when no files have changed' do
      Simp::RelChecks.expects(:`).with('git fetch -t origin 2>/dev/null').returns("\n")
      Simp::RelChecks.expects(:`).with('git tag -l').returns("1.0.0-pre\n1.0.0\n1.1.0\n")
      Simp::RelChecks.expects(:`).with('git diff tags/1.1.0 --name-only').returns("\n")

      msg = "  No new tag required: No significant files have changed since '1.1.0' tag\n"
      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to output(msg).to_stdout
    end

    it 'reports no new tag required when no significant files have changed' do
      Simp::RelChecks.expects(:`).with('git fetch -t origin 2>/dev/null').returns("\n")
      Simp::RelChecks.expects(:`).with('git tag -l').returns("1.0.0\nv1.0.1\n1.1.0\n")
      Simp::RelChecks.expects(:`).with('git diff tags/1.1.0 --name-only').returns(
        ".travis.yml\nRakefile\nGemfile.lock\nspec/some_spec.rb\ndoc/index.html\n")

      msg = "  No new tag required: No significant files have changed since '1.1.0' tag\n"
      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to output(msg).to_stdout
    end

    it 'reports a new tag is required for significant changes with bumped version' do
      Simp::RelChecks.expects(:`).with('git fetch -t origin 2>/dev/null').returns("\n")
      Simp::RelChecks.expects(:`).with('git tag -l').returns("1.0.0\n1.1.0-RC01\n")
      Simp::RelChecks.expects(:`).with('git diff tags/1.0.0 --name-only').returns(
         "CHANGELOG\nmetadata.json\nmanifest/init.pp\n")

      msg = <<-EOM
NOTICE: New tag of version '1.1.0' is required for 3 changed files:
  * CHANGELOG
  * metadata.json
  * manifest/init.pp
      EOM

      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to output(msg).to_stdout
    end
  end

  context 'with project errors' do
    it 'fails when latest version < latest tag' do
      Simp::RelChecks.expects(:`).with('git fetch -t origin 2>/dev/null').returns("\n")
      Simp::RelChecks.expects(:`).with('git tag -l').returns("1.0.0\n1.2.0\n")
      Simp::RelChecks.expects(:`).with('git diff tags/1.2.0 --name-only').returns(
         "CHANGELOG\nmetadata.json\nmanifest/init.pp\n")

      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to raise_error(/ERROR: Version regression. '1\.1\.0' < last tag '1\.2\.0'/)
    end

    it 'fails when significant file changes need a version bump' do
      Simp::RelChecks.expects(:`).with('git fetch -t origin 2>/dev/null').returns("\n")
      Simp::RelChecks.expects(:`).with('git tag -l').returns("1.0.0\n1.1.0\n")
      Simp::RelChecks.expects(:`).with('git diff tags/1.1.0 --name-only').returns(
         "manifest/init.pp\n")

      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to raise_error(/ERROR: Version update beyond last tag '1.1.0' is required for 1 changed files:/)
    end

    # spot check just one of many failures handled by
    # Simp::RelCheck.load_and_validate_changelog, as that method is 
    # extensively tested elsewhere.
    it 'fails when module info cannot be loaded' do
      comp_dir = File.join(files_dir, 'module_without_changelo')
      expect{ Simp::RelChecks.compare_latest_tag(comp_dir) }.
        to raise_error(/No RPM spec file found in/ )
    end
  end
end
