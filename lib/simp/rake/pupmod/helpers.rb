require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet/version'
require 'puppet-syntax/tasks/puppet-syntax'
require 'puppet-lint/tasks/puppet-lint'
require 'simp/rake/pkg'
require 'simp/rake/beaker'
require 'parallel_tests/cli'
require 'simp/rake/fixtures'

if Puppet.version.to_f >= 4.9
    require 'semantic_puppet'
elsif Puppet.version.to_f >= 3.6 && Puppet.version.to_f < 4.9
    require 'puppet/vendor/semantic/lib/semantic'
end

module Simp; end
module Simp::Rake; end
module Simp::Rake::Pupmod; end

# Rake tasks for SIMP Puppet modules
class Simp::Rake::Pupmod::Helpers < ::Rake::TaskLib
  def initialize( base_dir = Dir.pwd )
    @base_dir = base_dir
    Dir[ File.join(File.dirname(__FILE__),'*.rb') ].each do |rake_file|
      next if rake_file == __FILE__
      require rake_file
    end
    define_tasks
  end

  def define_tasks
    # These gems aren't always present, for instance
    # on Travis with --without development
    begin
      require 'puppet_blacksmith/rake_tasks'
      Blacksmith::RakeTask.new do |t|
        t.tag_pattern = "%s" # Use tage format "X.Y.Z" instead of "vX.Y.Z"
      end
    rescue LoadError
    end


    # Lint & Syntax exclusions
    exclude_paths = [
      "bundle/**/*",
      "pkg/**/*",
      "dist/**/*",
      "vendor/**/*",
      "spec/**/*",
    ]
    PuppetSyntax.exclude_paths = exclude_paths

    # See: https://github.com/rodjek/puppet-lint/pull/397
    Rake::Task[:lint].clear
    PuppetLint.configuration.ignore_paths = exclude_paths
    PuppetLint::RakeTask.new :lint do |config|
      config.ignore_paths = PuppetLint.configuration.ignore_paths
    end

    Simp::Rake::Fixtures.new( @base_dir )

    Simp::Rake::Pkg.new( @base_dir ) do | t |
      t.clean_list << "#{t.base_dir}/spec/fixtures/hieradata/hiera.yaml"
    end

    Simp::Rake::Beaker.new( @base_dir )

    desc "Run acceptance tests"
    RSpec::Core::RakeTask.new(:acceptance) do |t|
      t.pattern = 'spec/acceptance'
    end

    desc 'Populate CONTRIBUTORS file'
    task :contributors do
      system("git log --format='%aN' | sort -u > CONTRIBUTORS")
    end

    desc 'lint metadata.json'
    task :metadata do
      sh "metadata-json-lint metadata.json"
    end

    desc <<-EOM
      Generate an appropriate annotated tag entry from a CHANGELOG.

      * The entries are extracted from a match with the version from the module's
        metadata.json
      * If no match is found, the task will fail
      * Changelog entries must follow the format:
          * Wed Jul 05 2017 UserName <username@simp.com> - 1.2.3-4
          - The entry must start with *.  Any line beginning with * will be interpreted
            as an entry.
          - The dates must be RPM compatible, in chronological order
          - The user email must be contained in < >
          - The entry must be terminated by the release
      * Any entry that does not follow the prescribed format will not be annotated
        properly
    EOM
    # TODO: Hook in a query of the auto-generated specfile:
    #   `rpm -q --specfile dist/tmp/*.spec --changelog`
    # That will give Travis a way of warning us if the changelog
    # will prevent the rpm from building.
    task :changelog_annotation, [:debug] do |t,args|
      require 'json'

      module_version = JSON.parse(File.read('metadata.json'))['version']

      changelog = Hash.new
      delim = nil

      File.read('CHANGELOG').each_line do |line|
        if line =~ /^\*/
          if /^\*\s+((?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{2} \d{4})\s+(.+<.+>)(?:\s+|\s*-\s*)?(\d+\.\d+\.\d+)/.match(line).nil?
             warn "DEBUG: invalid changelog entry: #{line}" if args[:debug]
          else 
            delim           = Hash.new
            delim[:date]    = $1
            delim[:user]    = $2
            delim[:release] = $3

            changelog[delim[:release]] ||= Array.new
            changelog[delim[:release]] << line
          end
          next
        end

        if delim && delim[:release]
          changelog[delim[:release]] << '  ' + line
        end
      end

      fail "Did not find any changelog entries for version #{module_version}" if changelog[module_version].nil?
      puts changelog[module_version]
    end


    desc "Run syntax, lint, and spec tests."
    task :test => [
      :syntax,
      :lint,
      :spec_parallel,
      :metadata,
    ]

    desc <<-EOM
    Run parallel spec tests.
    This will NOT run acceptance tests.
    Use env var `SPEC_clean=yes` to run `:spec_clean` after tests
    EOM
    task :spec_parallel do
      test_targets = ['spec/classes', 'spec/defines', 'spec/unit', 'spec/functions']
      if ENV['SIMP_PARALLEL_TARGETS']
        test_targets += ENV['SIMP_PARALLEL_TARGETS'].split
      end
      test_targets.delete_if{|dir| !File.directory?(dir)}
      Rake::Task[:spec_prep].invoke
      ParallelTests::CLI.new.run('--type test -t rspec'.split + test_targets)
      if ENV.fetch('SPEC_clean', 'no') == 'yes'
        Rake::Task[:spec_clean].invoke
      end
    end
  end
end
