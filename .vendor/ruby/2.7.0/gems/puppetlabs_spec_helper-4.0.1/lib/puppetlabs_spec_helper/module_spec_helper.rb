# frozen_string_literal: true

require 'rspec-puppet'
require 'puppetlabs_spec_helper/puppet_spec_helper'
require 'puppetlabs_spec_helper/puppetlabs_spec/puppet_internals'

def param_value(subject, type, title, param)
  subject.resource(type, title).send(:parameters)[param.to_sym]
end

def verify_contents(subject, title, expected_lines)
  content = subject.resource('file', title).send(:parameters)[:content]
  expect(content.split("\n") & expected_lines).to match_array expected_lines.uniq
end

spec_path = File.expand_path(File.join(Dir.pwd, 'spec'))
fixture_path = File.join(spec_path, 'fixtures')

env_module_path = ENV['MODULEPATH']
module_path = File.join(fixture_path, 'modules')

module_path = [module_path, env_module_path].join(File::PATH_SEPARATOR) if env_module_path
if ENV['SIMPLECOV'] == 'yes'
  begin
    require 'simplecov'
    require 'simplecov-console'
    require 'codecov'

    SimpleCov.formatters = [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console,
      SimpleCov::Formatter::Codecov,
    ]
    SimpleCov.start do
      track_files 'lib/**/*.rb'
      add_filter '/spec'

      # do not track vendored files
      add_filter '/vendor'
      add_filter '/.vendor'

      # do not track gitignored files
      # this adds about 4 seconds to the coverage check
      # this could definitely be optimized
      add_filter do |f|
        # system returns true if exit status is 0, which with git-check-ignore means file is ignored
        system("git check-ignore --quiet #{f.filename}")
      end
    end
  rescue LoadError
    raise 'Add the simplecov, simplecov-console, codecov gems to Gemfile to enable this task'
  end
end

# Add all spec lib dirs to LOAD_PATH
components = module_path.split(File::PATH_SEPARATOR).collect do |dir|
  next unless Dir.exist? dir
  Dir.entries(dir).reject { |f| f =~ %r{^\.} }.collect { |f| File.join(dir, f, 'spec', 'lib') }
end
components.flatten.each do |d|
  $LOAD_PATH << d if FileTest.directory?(d) && !$LOAD_PATH.include?(d)
end

RSpec.configure do |c|
  c.environmentpath = spec_path if Puppet.version.to_f >= 4.0
  c.module_path = module_path
  c.manifest_dir = File.join(fixture_path, 'manifests')
  c.parser = 'future' if ENV['FUTURE_PARSER'] == 'yes'

  c.before :each do
    if c.mock_framework.framework_name == :rspec
      allow(Puppet.features).to receive(:root?).and_return(true)
    else
      Puppet.features.stubs(:root?).returns(true)
    end

    # stringify_facts and trusted_node_data were removed in puppet4
    if Puppet.version.to_f < 4.0
      Puppet.settings[:stringify_facts] = false if ENV['STRINGIFY_FACTS'] == 'no'
      Puppet.settings[:trusted_node_data] = true if ENV['TRUSTED_NODE_DATA'] == 'yes'
    end
    Puppet.settings[:strict_variables] = true if ENV['STRICT_VARIABLES'] == 'yes' || (Puppet.version.to_f >= 4.0 && ENV['STRICT_VARIABLES'] != 'no')
    Puppet.settings[:ordering] = ENV['ORDERING'] if ENV['ORDERING']
  end
end
