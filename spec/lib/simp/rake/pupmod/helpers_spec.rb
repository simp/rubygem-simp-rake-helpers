require 'simp/rake/pupmod/helpers'
require 'spec_helper'

describe Simp::Rake::Pupmod::Helpers do
  before :each do
    fixtures_dir = File.expand_path( '../fixtures', __FILE__ )
    @simpmod = Simp::Rake::Pupmod::Helpers.new(File.join(fixtures_dir, 'simpmod'))
    @othermod = Simp::Rake::Pupmod::Helpers.new(File.join(fixtures_dir, 'othermod'))
  end

  describe '#initialize' do
    it 'initialized (smoke test)' do
      expect( @simpmod.class ).to eq Simp::Rake::Pupmod::Helpers
    end
  end

  describe '#metadata' do
    it 'reads a valid metadata.json (simp)' do
      expect( @simpmod.send( :metadata )['name'] ).to eq 'simp-simpmod'
      expect( @othermod.send( :metadata )['name'] ).to eq 'other-othermod'
    end
  end

  describe '::CHANGELOG_ENTRY_REGEX' do
    before :all do
      @rgx = Simp::Rake::Pupmod::Helpers::CHANGELOG_ENTRY_REGEX
    end

    it 'matches valid one-line CHANGELOG entries' do
      expect("* Mon Jan 1 1970 First Last <email@domain.com> - 0.0.1\n").to match @rgx
      expect("* Mon Jan 1 1970 First Last <email@domain.com> 0.0.1\n").to match @rgx
      expect("* Wed Oct 22 2014 First Middle Last <first.last-a1999@domain.com> - 2.0.0\n").to match @rgx
      expect('* Wed Oct 22 2014 Name <first.last-a1999+gmail.label@domain.com> - 2.0.0').to match @rgx
      expect('* Fri Jul 02 2010 Kamil Dudka <kdudka@redhat.com> 2.1.5-20').to match @rgx
      expect('* Tue Feb 08 2011 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 2.1.5-21').to match @rgx
    end

    it "doesn't match invalid one-line CHANGELOG entries" do
      expect("* Foo Jan 1 1970 First Last <email@domain.com> - 0.0.1\n").to_not match @rgx
      expect("* Mon Xxn 1 1970 First Last <email@domain.com> - 0.0.1\n").to_not match @rgx
      expect("* Mon Jan 111 1970 First Last <email@domain.com> - 0.0.1\n").to_not match @rgx
      expect("* Mon Jan 1 1970 <email@domain.com> - 0.0.1\n").to_not match @rgx
    end

    it 'matches valid two-line CHANGELOG entries' do
      skip "Not worth implementing right now"
    end
  end

  describe "#changelog_annotation" do
    it "generates a tag annotation from a valid SIMP module's CHANGELOG" do
      _log = @simpmod.send( :changelog_annotation )
      expect( _log.class ).to be String
      expect( _log.size ).to be > 0
      expect( _log.scan( /^Release of/ ).size ).to eq 1
    end

    it 'handles multiple CHANGELOG entries for the same release' do
      _log = @simpmod.send( :changelog_annotation )
      expect( _log.scan(/^\*.*\d+\.\d+\.\d+$/) ).to eq [
        '* Tue Jan 2 1970 Second Author <email1@domain.com> - 0.1.0',
        '* Mon Jan 1 1970 First Author <email2@domain.com> - 0.1.0',
      ]
    end
  end
end

