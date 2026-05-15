# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

require 'rake'
# The library defines `namespace :pupmod` at the top level, which requires
# Rake::DSL to be available. In a Rakefile this is implicit; here we make
# it explicit before loading the file under test. record_task_metadata must
# also be enabled before load, otherwise task descriptions are discarded.
extend Rake::DSL
Rake::TaskManager.record_task_metadata = true

require 'simp/rake/pupmod/module_build'
require 'spec_helper'

describe Simp::Rake::Pupmod::PdkCompatBuilder do
  around(:each) do |example|
    Dir.mktmpdir('module_build_spec') do |dir|
      @source = dir
      File.write(File.join(dir, 'metadata.json'), '{"name":"simp-test","version":"0.0.1"}')
      example.run
    end
  end

  let(:builder) { described_class.new(@source) }

  describe '#ignored_files' do
    context 'when no .pdkignore is present' do
      it "delegates to the parent class's default ignore list" do
        spec = builder.ignored_files
        expect(spec).to be_a(PathSpec)
        # Parent's IGNORED list includes /pkg/ and metadata.json is explicitly NOT ignored
        expect(spec.match('pkg/')).to be true
        expect(spec.match('metadata.json')).to be false
      end
    end

    context 'when a .pdkignore is present' do
      before(:each) do
        File.write(File.join(@source, '.pdkignore'), "/spec/\ncustom_excluded_dir/\n")
      end

      it 'returns a PathSpec built from the .pdkignore patterns' do
        spec = builder.ignored_files
        expect(spec).to be_a(PathSpec)
        expect(spec.match('spec/')).to be true
        expect(spec.match('custom_excluded_dir/')).to be true
      end

      it 'ignores dotfiles in addition to patterns from .pdkignore' do
        spec = builder.ignored_files
        expect(spec.match('.git')).to be true
        expect(spec.match('.travis.yml')).to be true
      end

      it 'does not ignore files that are not listed' do
        spec = builder.ignored_files
        expect(spec.match('manifests/init.pp')).to be false
        expect(spec.match('metadata.json')).to be false
      end
    end
  end
end

describe 'pupmod:build rake task' do
  before(:all) do
    require 'rake'
    # The task is registered at file load time; ensure it's defined.
    require 'simp/rake/pupmod/module_build'
  end

  it 'is defined' do
    expect(Rake::Task.task_defined?('pupmod:build')).to be true
  end

  it 'has a description' do
    expect(Rake::Task['pupmod:build'].comment).to match(/build the puppet module package/i)
  end

  it 'has a single action defined in module_build.rb' do
    actions = Rake::Task['pupmod:build'].actions
    expect(actions.size).to eq 1
    expect(actions.first.source_location.first).to end_with('module_build.rb')
  end
end
