require 'simp/relchecks'
require 'spec_helper'

describe 'Simp::RelChecks.compare_latest_tag' do
  let(:files_dir) {
    File.join( File.dirname(__FILE__), 'files', File.basename(__FILE__, '.rb'))
  }

  let(:component_dir) {  File.join(files_dir, 'module') }

  context 'with no project errors' do
    it 'reports no tags for a project with no tags' do
      expect(Simp::RelChecks).to receive(:`).with('git fetch -t origin 2>/dev/null').and_return("\n")
      expect(Simp::RelChecks).to receive(:`).with('git tag -l').and_return("\n")

      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to output("  No tags exist from origin\n").to_stdout
    end

    it 'reports no new tag required when no files have changed' do
      expect(Simp::RelChecks).to receive(:`).with('git fetch -t origin 2>/dev/null').and_return("\n")
      expect(Simp::RelChecks).to receive(:`).with('git tag -l').and_return("1.0.0-pre\n1.0.0\n1.1.0\n")
      expect(Simp::RelChecks).to receive(:`).with('git diff tags/1.1.0 --name-only').and_return("\n")

      msg = "  No new tag required: No significant files have changed since '1.1.0' tag\n"
      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to output(msg).to_stdout
    end

    it 'reports no new tag required when no significant files have changed' do
      expect(Simp::RelChecks).to receive(:`).with('git fetch -t origin 2>/dev/null').and_return("\n")
      expect(Simp::RelChecks).to receive(:`).with('git tag -l').and_return("1.0.0\nv1.0.1\n1.1.0\n")
      expect(Simp::RelChecks).to receive(:`).with('git diff tags/1.1.0 --name-only').and_return(
        ".travis.yml\nRakefile\nREFERENCE.md\nGemfile.lock\nspec/some_spec.rb\ndoc/index.html\nrakelib/mytasks.rake\nrenovate.json\n")

      msg = "  No new tag required: No significant files have changed since '1.1.0' tag\n"
      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to output(msg).to_stdout
    end

    it 'reports a new tag is required for significant changes with bumped version' do
      expect(Simp::RelChecks).to receive(:`).with('git fetch -t origin 2>/dev/null').and_return("\n")
      expect(Simp::RelChecks).to receive(:`).with('git tag -l').and_return("1.0.0\n1.1.0-RC01\n")
      expect(Simp::RelChecks).to receive(:`).with('git diff tags/1.0.0 --name-only').and_return(
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
      expect(Simp::RelChecks).to receive(:`).with('git fetch -t origin 2>/dev/null').and_return("\n")
      expect(Simp::RelChecks).to receive(:`).with('git tag -l').and_return("1.0.0\n1.2.0\n")
      expect(Simp::RelChecks).to receive(:`).with('git diff tags/1.2.0 --name-only').and_return(
         "CHANGELOG\nmetadata.json\nmanifest/init.pp\n")

      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to raise_error(/ERROR: Version regression. '1\.1\.0' < last tag '1\.2\.0'/)
    end

    it 'fails when significant file changes need a version bump' do
      expect(Simp::RelChecks).to receive(:`).with('git fetch -t origin 2>/dev/null').and_return("\n")
      expect(Simp::RelChecks).to receive(:`).with('git tag -l').and_return("1.0.0\n1.1.0\n")
      expect(Simp::RelChecks).to receive(:`).with('git diff tags/1.1.0 --name-only').and_return(
         "manifest/init.pp\n")

      expect{ Simp::RelChecks.compare_latest_tag(component_dir) }.
        to raise_error(/ERROR: Version update beyond last tag '1.1.0' is required for 1 changed files:/)
    end

    # spot check just one of many failures handled by
    # Simp::RelCheck.load_and_validate_changelog, as that method is
    # extensively tested elsewhere.
    it 'fails when module info cannot be loaded' do
      comp_dir = File.join(files_dir, 'module_without_changelog')
      expect{ Simp::RelChecks.compare_latest_tag(comp_dir) }.
        to raise_error(/No CHANGELOG file found in/ )
    end
  end

  # If the environment variable `SIMP_SPEC_changelog` is the path to a file,
  # test to see if will be considered a valid CHANGELOG (useful for debugging)
  context 'with custom CHANGELOG at $SIMP_SPEC_changelog' do
    _changelog_file = ENV['SIMP_SPEC_changelog'].to_s
    if File.file?( _changelog_file )
      it "validates the CHANGELOG file at '#{_changelog_file}'" do
        comp_dir = File.dirname( _changelog_file )
        expect{ Simp::RelChecks.load_and_validate_changelog(comp_dir, true) }.not_to raise_error
      end
    else
        skip 'This test is disabled by default.'
    end
  end
end
