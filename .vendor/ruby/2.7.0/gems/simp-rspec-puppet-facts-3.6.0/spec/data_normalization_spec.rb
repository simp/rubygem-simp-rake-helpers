require 'spec_helper'

describe 'Simp::RspecPuppetFacts' do
  facts_top_path = File.expand_path('../facts', File.dirname(__FILE__))
  facter_paths = Dir[File.join(facts_top_path,'?.?')].sort

  facter_paths.each do |facter_path|
  warn "=== facter_path = '#{facter_path}'"
    facter_version = File.basename(facter_path)
    describe "factsets for Facter #{facter_version}" do
      Dir[File.join(facter_path,'*.facts')].each do |facts_file|
        os = File.basename(facts_file).sub(/\.facts$/,'')
        context "for #{os}" do
          before :all do
            @facts = YAML.load_file facts_file
          end

          it 'should use the fqdn "foo.example.com"' do
            expect(@facts['fqdn']).to be == 'foo.example.com'
          end

          it 'should use the ipaddress "10.0.2.15"' do
            expect(@facts['ipaddress']).to be == '10.0.2.15'
          end

          it 'should have a grub_version' do
            expect(@facts['grub_version']).to match /^(0\.9|2\.)/
          end
        end
      end
    end
  end

end
