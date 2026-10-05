# frozen_string_literal: true

require 'simp/relchecks'
require 'spec_helper'

describe 'Simp::RelChecks.significant_file?' do
  context 'with a Puppet module' do
    [
      'CHANGELOG', 'LICENSE', 'README.md', 'REFERENCE.md', 'metadata.json', 'hiera.yaml',
      'SIMP/compliance_profiles/checks.yaml', 'build/rpm_metadata/requires', 'data/common.yaml',
      'facts.d/x.sh', 'files/x.conf', 'functions/x.pp', 'lib/facter/x.rb', 'locales/config.yaml',
      'manifests/init.pp', 'manifests/README.md', 'plans/x.pp', 'tasks/x.json', 'templates/x.epp', 'types/x.pp'
    ].each do |file|
      it "considers #{file} significant" do
        expect(Simp::RelChecks.significant_file?(file, :module)).to be true
      end
    end

    [
      'AGENTS.md', 'CLAUDE.md', 'Gemfile', 'Gemfile.project', 'Rakefile',
      'renovate.json', '.github/workflows/pr_tests.yml', '.fixtures.yml', 'spec/classes/init_spec.rb',
      'examples/init.pp', 'doc/index.html', 'rakelib/x.rake', 'metadata.json.bak', 'manifest/init.pp'
    ].each do |file|
      it "does not consider #{file} significant" do
        expect(Simp::RelChecks.significant_file?(file, :module)).to be false
      end
    end
  end

  context 'with a non-module component' do
    ['build/simp.spec', 'src/x.sh', 'examples/x.conf', 'LICENSE'].each do |file|
      it "considers #{file} significant" do
        expect(Simp::RelChecks.significant_file?(file, :asset)).to be true
      end
    end

    [
      '.github/workflows/pr_tests.yml', 'Gemfile', 'Gemfile.lock', 'Rakefile', 'README.md',
      'docs/x.md', 'spec/x_spec.rb', 'doc/index.html', 'rakelib/x.rake', 'renovate.json'
    ].each do |file|
      it "does not consider #{file} significant" do
        expect(Simp::RelChecks.significant_file?(file, :asset)).to be false
      end
    end
  end
end
