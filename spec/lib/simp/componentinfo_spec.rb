require 'simp/componentinfo'
require 'spec_helper'

describe Simp::ComponentInfo do
  let(:files_dir) {
    File.join( File.dirname(__FILE__), 'files', File.basename(__FILE__, '.rb'))
  }

  context 'with valid module input' do
    it 'loads version and changelog info' do
      component_dir = File.join(files_dir, 'module')
      info = Simp::ComponentInfo.new(component_dir)
      expect( info.component_dir ).to eq component_dir
      expect( info.type ).to eq :module
      expect( info.version ).to eq '3.8.0'
      expect( info.release ).to be nil
      expected_changelog = [
        {
          :date => 'Wed Nov 15 2017',
          :version => '3.8.0',
          :release => '0',
          :content => [
            '* Wed Nov 15 2017 Mary Jones <mary.jones@simp.com> - 3.8.0-0',
            '- Disable deprecation warnings by default'
          ]
        },
        {
          :date => 'Mon Nov 06 2017',
          :version => '3.8.0',
          :release => '0',
          :content => [
            '* Mon Nov 06 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0',
            '- Fixes split failure when "findmnt" does not exist on Linux'
          ]
        },
        {
          :date => 'Thu Oct 26 2017',
          :version => '3.7.0',
          :release => '0',
          :content => [  # +changelog_date+:: Date string of the form <weekday> <month> <day> <year>

            '* Thu Oct 26 2017 Mary Jones <mary.jones@simp.com> - 3.7.0-0',
            '- Add Mod::Macaddress data type'
          ]
        },
        {
          :date => 'Tue Sep 26 2017',
          :version => '3.6.0',
          :release => '0',
          :content => [
            '* Tue Sep 26 2017 Joe Brown <joe.brown@simp.com> - 3.6.0-0',
            "- Convert all 'sysctl' 'kernel.shm*' entries to Strings",
            '  - shmall and shmmax were causing Facter and newer versions of Puppet to crash',
            '  - See FACT-1732 for additional information',
            '- Add Puppet function `mod::assert_metadata_os()`'
          ]
        }
      ]
      expect(info.changelog).to eq expected_changelog
    end

    it 'loads version and latest changelog info' do
      component_dir = File.join(files_dir, 'module')
      info = Simp::ComponentInfo.new(component_dir, true)
      expect( info.component_dir ).to eq component_dir
      expect( info.type ).to eq :module
      expect( info.version ).to eq '3.8.0'
      expect( info.release ).to be nil
      expected_changelog = [
        {
          :date => 'Wed Nov 15 2017',
          :version => '3.8.0',
          :release => '0',
          :content => [
            '* Wed Nov 15 2017 Mary Jones <mary.jones@simp.com> - 3.8.0-0',
            '- Disable deprecation warnings by default'
          ]
        },
        {
          :date => 'Mon Nov 06 2017',
          :version => '3.8.0',
          :release => '0',
          :content => [
            '* Mon Nov 06 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0',
            '- Fixes split failure when "findmnt" does not exist on Linux'
          ]
        }
      ]
      expect(info.changelog).to eq expected_changelog
    end
  end

  context 'with invalid module input' do
    it 'fails when metadata.json is malformed' do
      component_dir = File.join(files_dir, 'module_with_malformed_metadata')
      expect{ Simp::ComponentInfo.new(component_dir) }.to raise_error(
        JSON::ParserError)
    end

    it 'fails when version is missing from metadata.json' do
      component_dir = File.join(files_dir, 'module_missing_version_metadata')
      expect{ Simp::ComponentInfo.new(component_dir) }.to raise_error(
        /Version missing from .*module_missing_version_metadata\/metadata.json/)
    end

    it 'fails when module CHANGELOG is missing' do
      component_dir = File.join(files_dir, 'module_without_changelog')
      expect{ Simp::ComponentInfo.new(component_dir) }.to raise_error(
        /No CHANGELOG file found in .*module_without_changelog/)
    end

    it 'fails when any changelog entry version is > top-most version' do
      component_dir = File.join(files_dir, 'module_with_version_misordered_entries')
      expect{ Simp::ComponentInfo.new(component_dir) }.to raise_error(
        /ERROR:  Changelog entries are not properly version ordered/)
    end

    it 'fails when changelog entry dates are not ordered newest to oldest' do
      component_dir = File.join(files_dir, 'module_with_date_misordered_entries')
      expect{ Simp::ComponentInfo.new(component_dir) }.to raise_error(
        /ERROR:  Changelog entries are not properly date ordered/)
    end

    it 'stops processing upon first malformed changelog signature' do
      component_dir = File.join(files_dir, 'module_with_invalid_entries')
      info = Simp::ComponentInfo.new(component_dir)
      expected_changelog = [
        {
          :date => 'Wed Nov 15 2017',
          :version => '3.8.0',
          :release => '0',
          :content => [
            '* Wed Nov 15 2017 Mary Jones <mary.jones@simp.com> - 3.8.0-0',
            '- Disable deprecation warnings by default'
          ]
        }
      ]
      expect(info.changelog).to eq expected_changelog
    end

    it 'stops processing upon first invalid changelog weekday' do
      component_dir = File.join(files_dir, 'module_with_invalid_weekday_entry')
      info = Simp::ComponentInfo.new(component_dir)
      expected_changelog = [
        {
          :date => 'Thu Nov 16 2017',
          :version => '3.8.0',
          :release => '0',
          :content => [
            '* Thu Nov 16 2017 Mary Jones <mary.jones@simp.com> - 3.8.0-0',
            '- Disable deprecation warnings by default'
          ]
        }
      ]
      expect(info.changelog).to eq expected_changelog
    end
  end

  context 'with valid asset input' do
   it 'loads version, release and changelog info from a single-package spec file' do
      component_dir = File.join(files_dir, 'asset_with_single_package')
      info = Simp::ComponentInfo.new(component_dir, true)
      expect( info.component_dir ).to eq component_dir
      expect( info.type ).to eq :asset
      expect( info.version ).to eq '1.0.0'
      expect( info.release ).to eq '1'
      expected_changelog = [
        {
          :date => 'Wed Oct 18 2017',
          :version => '1.0.0',
          :release => '1',
          :content => [
            '* Wed Oct 18 2017 Jane Doe <jane.doe@simp.com> - 1.0.0-1',
            '- Fix installed file permissions'
          ]
        }
      ]
      expect(info.changelog).to eq expected_changelog
    end

    it 'loads version, release, and changelog info for primary package from a multi-package spec file' do
      component_dir = File.join(files_dir, 'asset_with_multiple_packages')
      info = Simp::ComponentInfo.new(component_dir)
      expect( info.component_dir ).to eq component_dir
      expect( info.type ).to eq :asset
      expect( info.version ).to eq '4.0.3'
      expect( info.release ).to eq '0'
      expected_changelog = [
        {
          :date => 'Thu Aug 31 2017',
          :version => '4.0.3',
          :release => nil,
          :content => [
            '* Thu Aug 31 2017 Jane Doe <jane.doe@simp.com> - 4.0.3',
            '- Fix bug Z',
            '  - Thanks to Lilia Smith for the PR!'
          ]
        },
        {
          :date => 'Mon Jun 12 2017',
          :version => '4.0.3',
          :release => nil,
          :content => [
            '* Mon Jun 12 2017 Jane Doe <jane.doe@simp.com> - 4.0.3',
            '- Prompt user for new input'
          ]
        },
        {
          :date => 'Fri Jun 02 2017',
          :version => '4.0.2',
          :release => '0',
          :content => [
            '* Fri Jun 02 2017 Jim Jones <jim.jones@simp.com> - 4.0.2-0',
            '- Expand X',
            '- Fix Y'
          ]
        }
      ]
      expect(info.changelog).to eq expected_changelog
    end

    it 'loads version, release, and changelog info when release includes distribution' do
      component_dir = File.join(files_dir, 'asset_with_dist_in_release')
      info = Simp::ComponentInfo.new(component_dir)
      expect( info.component_dir ).to eq component_dir
      expect( info.type ).to eq :asset
      expect( info.version ).to eq '1.0.0'
      expect( info.release ).to match /0/
      expected_changelog = [
        {
          :date => 'Wed Oct 18 2017',
          :version => '1.0.0',
          :release => '0',
          :content => [
            '* Wed Oct 18 2017 Jane Doe <jane.doe@simp.com> - 1.0.0-0',
            '- Package with distribution in release tag'
          ]
        }
      ]
      expect(info.changelog).to eq expected_changelog
    end
  end

 # Since same changelog parsing code is used for module and
 # RPM changelog content, only focus on the errors not already
 # tested above.
  context 'with invalid asset input' do
    it 'fails when asset RPM spec file is missing' do
      component_dir = File.join(files_dir, 'asset_without_spec_file')
      expect{ Simp::ComponentInfo.new(component_dir) }.to raise_error(
        /No RPM spec file found in .*asset_without_spec_file\/build/)
   end

   it 'fails when more than 1 asset RPM spec file is found' do
     component_dir = File.join(files_dir, 'asset_with_two_spec_files')
     expect{ Simp::ComponentInfo.new(component_dir) }.to raise_error(
       /More than 1 RPM spec file found:/)
   end

   it 'fails when version is missing from asset RPM spec file' do
     component_dir = File.join(files_dir, 'asset_missing_version')
     expect{ Simp::ComponentInfo.new(component_dir) }.to raise_error(
       /Could not extract version and release from /)
   end

   it 'fails when release is missing from asset RPM spec file' do
     component_dir = File.join(files_dir, 'asset_missing_release')
     expect{ Simp::ComponentInfo.new(component_dir) }.to raise_error(
       /Could not extract version and release from /)
   end

   # This has to be a case in which version and release can be read
   # from spec file but the changelog (which is optional) can't.  Could
   # be mocked, but would like a real-world test case.
   xit 'fails when changelog cannot be read from asset RPM spec file'

  end
end
