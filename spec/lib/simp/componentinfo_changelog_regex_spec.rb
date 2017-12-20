require 'simp/relchecks'
require 'spec_helper'

describe 'Simp::ComponentInfo changelog regex' do

  context 'valid initial changelog lines' do
    it 'matches a valid line with a hyphen before version' do
      line = '* Mon Nov 06 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      result = line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX)
      expect( result ).to_not be nil
      expect( result[1] ).to eq 'Mon Nov 06 2017'
      expect( result[2] ).to eq 'Tom Smith <tom.smith@simp.com>'
      expect( result[3] ).to eq '3.8.0'
      expect( result[4] ).to eq '0'
    end

    it 'matches a valid line without a hyphen before version' do
      line = '* Mon Nov 06 2017 Tom Smith <tom.smith@simp.com>  13.28.30-RC1 '
      result = line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX)
      expect( result ).to_not be nil
      expect( result[1] ).to eq 'Mon Nov 06 2017'
      expect( result[2] ).to eq 'Tom Smith <tom.smith@simp.com>'
      expect( result[3] ).to eq '13.28.30'
      expect( result[4] ).to eq 'RC1'
    end

    it 'matches a valid line without release qualifier' do
      line = '* Mon Nov 06 2017 Tom Smith <tom.smith@simp.com> - 3.8.0'
      result = line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX)
      expect( result ).to_not be nil
      expect( result[1] ).to eq 'Mon Nov 06 2017'
      expect( result[2] ).to eq 'Tom Smith <tom.smith@simp.com>'
      expect( result[3] ).to eq '3.8.0'
      expect( result[4] ).to be nil
    end
  end

  context 'invalid initial changelog lines' do
    it "does not match line that does not begin with '*'" do
      line = '- Mon Nov 06 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line with bad weekday' do
      line = '* Tues Nov 06 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line missing weekday' do
      line = '* Nov 06 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line with invalid month' do
      line = '* Mon June 06 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line missing month' do
      line = '* Mon 06 06 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line with single digit day' do
      line = '* Mon Nov 6 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line with a too-large day' do
      line = '* Mon Nov 46 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line missing day' do
      line = '* Mon Nov 2017 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line with a two-digit year' do
      line = '* Mon Nov 01 17 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line with a too-large year' do
      line = '* Mon Nov 01 20170 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line missing year' do
      line = '* Mon Nov 01 Tom Smith <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line missing author name' do
      line = '* Mon Nov 01 2017 <tom.smith@simp.com> - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line missing author email address' do
      line = '* Mon Nov 01 20170 Tom Smith - 3.8.0-0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line missing version' do
      line = '* Mon Nov 06 2017 Tom Smith <tom.smith@simp.com>'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match line with a version less than 3 parts' do
      line = '* Mon Nov 01 20170 Tom Smith <tom.smith@simp.com> - 3.8'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

    it 'does not match a valid line with more than 3 parts in the version' do
      line = '* Mon Nov 06 2017 Tom Smith <tom.smith@simp.com>  3.8.0.0'
      expect( line.match(Simp::ComponentInfo::CHANGELOG_ENTRY_REGEX) ).to be nil
    end

  end
end
