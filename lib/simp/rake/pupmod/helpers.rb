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

      ARGS:
        * :quiet => Set to 'true' if you want to suppress warning messages

      NOTES:
        * The entries are extracted from a match with the version from the
          module's metadata.json
        * If no match is found, the task will fail
        * Changelog entries must follow the format:
          * Wed Jul 05 2017 UserName <username@simp.com> - 1.2.3-4
            - The entry must start with *. Any line beginning with * will be
              interpreted as an entry.
            - The dates must be RPM compatible, in chronological order
            - The user email must be contained in < >
            - The entry must be terminated by the release
        * Any entry that does not follow the prescribed format will not be
          annotated properly
    EOM
    # TODO: Hook in a query of the auto-generated specfile:
    #   `rpm -q --specfile dist/tmp/*.spec --changelog`
    # That will give Travis a way of warning us if the changelog
    # will prevent the rpm from building.
    task :changelog_annotation, [:quiet] do |t,args|
      require 'json'

      quiet = true if args[:quiet].to_s == 'true'

      module_version = JSON.parse(File.read('metadata.json'))['version']

      changelog = Hash.new
      delim = nil
      ignore_line = false

      File.read('CHANGELOG').each_line do |line|
        if line =~ /^\*/
          if /^\*\s+((?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{2} \d{4})\s+(.+<.+>)(?:\s+|\s*-\s*)?(\d+\.\d+\.\d+)/.match(line).nil?
             warn "WARNING: invalid changelog entry: #{line}" unless quiet
             # Don't add anything to the annotation until we reach the next
             # valid entry
             ignore_line = true
          else
            ignore_line = false
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
          changelog[delim[:release]] << '  ' + line unless ignore_line
        end
      end

      fail "Did not find any changelog entries for version #{module_version}" if changelog[module_version].nil?
      puts "\nRelease of #{module_version}\n\n"
      puts changelog[module_version]
    end

    desc <<-EOM
    Compare to latest tag.
      ARGS:
        * :tags_source => Set to the remote from which the tags for this
                      project can be fetched, e.g. 'upstream' for a
                      forked project. Defaults to 'origin'.
        * :ignore_owner => Execute comparison even if the project owner
                      is not 'simp'.
        * :verbose => Set to 'true' if you want to see detailed messages

      NOTES:
      Compares mission-impacting (significant) files with the latest
      tag and identifies the relevant files that have changed.  

      Does nothing if the project owner, as specified in the
      metadata.json file, is not 'simp'.

      When mission-impacting files have changed, fails if
      (1) Latest version cannot be extracted from the top-most
          CHANGELOG entry.
      (2) The latest version in the CHANGELOG (minus the release
          qualifier) does not match the version in the metadata.json
          file.
      (3) A version bump is required but not recorded in both the
          CHANGELOG and metadata.json files.
      (4) The latest version is < latest tag.

      Changes to the following files/directories are not considered
      significant:
      - Any hidden file/directory (entry that begins with a '.')
      - Gemfile
      - Gemfile.lock
      - Rakefile
      - spec directory
      - doc directory
    EOM
    task :compare_latest_tag, [:tags_source, :ignore_owner, :verbose] do |t,args|
      require 'json'
      require 'puppet/util/package'

      tags_source = args[:tags_source].nil? ? 'origin' : args[:tags_source]
      ignore_owner = true if args[:ignore_owner].to_s == 'true' 
      verbose = true if args[:verbose].to_s == 'true' 

      metadata = JSON.load(File.read('metadata.json'))
      module_version = metadata['version']
      owner =  metadata['name'].split('-')[0]

      if (owner == 'simp') or ignore_owner
        # determine last tag
        `git fetch -t #{tags_source} 2>/dev/null`
        tags = `git tag -l`.split("\n")
        puts "Available tags from #{tags_source} = #{tags}" if verbose
        tags.delete_if { |tag| tag.include?('-') or (tag =~ /^v/) }

        if tags.empty?
          puts "No tags exist from #{tags_source}"
        else
          last_tag = (tags.sort { |a,b| Puppet::Util::Package::versioncmp(a,b) })[-1]

          # determine mission-impacting files that have changed
          files_changed = `git diff tags/#{last_tag} --name-only`.strip.split("\n")
          files_changed.delete_if do |file|
            file[0] ==  '.' or file =~ /^Gemfile/ or file == 'Rakefile' or file =~/^spec\// or file =~/^doc/
          end
        
          if files_changed.empty?
            puts "  No new tag required: No significant files have changed since '#{last_tag}' tag"
          else
            # determine latest CHANGELOG version
            line = IO.readlines('CHANGELOG')[0]
            match = line.match(/^\*\s+((?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{2} \d{4})\s+(.+<.+>)(?:\s+|\s*-\s*)?(\d+\.\d+\.\d+)/)
            unless match
              fail("ERROR: Invalid CHANGELOG entry. Unable to extract version from '#{line}'")
            end

            changelog_version = match[3]
            unless module_version == changelog_version
              fail("ERROR: Version mismatch.  module version=#{module_version}  changelog version=#{changelog_version}")
            end

            cmp_result = Puppet::Util::Package::versioncmp(module_version, last_tag)
            if cmp_result < 0
              fail("ERROR: Version regression. '#{module_version}' < last tag '#{last_tag}'")
            elsif cmp_result == 0
              fail("ERROR: Version update beyond last tag '#{last_tag}' is required for changes to #{files_changed}")
            else
              puts "  New tag of version '#{module_version}' is required for changes to #{files_changed}"
            end
          end
        end
      else     
        puts "  Not evaluating module owned by '#{owner}'"
      end
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
