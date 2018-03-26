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

# From http://dan.doezema.com/2012/04/recursively-sort-ruby-hash-by-key/
class Hash
  def sort_by_key(recursive = false, &block)
    self.keys.sort(&block).reduce({}) do |seed, key|
      seed[key] = self[key]
      if recursive && seed[key].is_a?(Hash)
        seed[key] = seed[key].sort_by_key(true, &block)
      end
      seed
    end
  end
end

# Rake tasks for SIMP Puppet modules
class Simp::Rake::Pupmod::Helpers < ::Rake::TaskLib
  # See https://fedoraproject.org/wiki/Packaging:Guidelines?rd=Packaging/Guidelines#Changelogs
  CHANGELOG_ENTRY_REGEX = /^\*\s+((?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{1,2} \d{4})\s+(.+<.+>)(?:\s+|\s*-\s*)?(\d+\.\d+\.\d+)/

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
      t.clean_list << "#{t.base_dir}/spec/fixtures/simp_rspec"
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
    Rake::Task[:metadata].clear
    task :metadata => :metadata_lint

    # Read the metadata.json as a data structure
    def metadata( file_path = nil )
      require 'json'
      _file = file_path || File.join(@base_dir, 'metadata.json')
      fail "ERROR: file not found: '#{_file}'" unless File.exists? _file
      @metadata ||= JSON.parse( File.read(_file) )
    end


    # Generate an appropriate annotated tag entry from the modules' CHANGELOG
    #
    # @note this currently does not support the valid RPM `%changelog` format
    #       that places the version number on the next line:
    #
    #       * Fri Mar 02 2012 Maintenance
    #       4.0.0-2
    #       - Improved test stubs.
    #
    def changelog_annotation( quiet = false, file = nil )
      result         = ""
      changelog_file = file || File.join(@base_dir, 'CHANGELOG')
      module_version = metadata['version']
      changelogs      = {}

      _entry = {} # current log entry's metadata (empty unless valid entry)
      File.read(changelog_file).each_line do |line|
        if line =~ /^\*/
          if CHANGELOG_ENTRY_REGEX.match(line).nil?
             warn %Q[WARNING: invalid changelogs entry: "#{line}"] unless quiet
             _entry = {}
          else
            _entry = {
              :date    => $1,
              :user    => $2,
              :release => $3,
            }
            changelogs[_entry[:release]] ||= []
            changelogs[_entry[:release]] << line
            next
          end
        end

        # Don't add anything to the annotation unless reach the next valid entry
        changelogs[_entry[:release]] << "  #{line}" if _entry.fetch(:release, false)
      end

      fail "Did not find any changelogs entries for version #{module_version}" if changelogs[module_version].nil?

      result += "\nRelease of #{module_version}\n\n"
      result += changelogs[module_version].join
    end

    def custom_fixtures_hook(opts = {
      :short_name          => nil,
      :puppetfile          => nil,
      :modulepath          => nil,
      :local_fixtures_mods => nil,
    })
      short_name          = opts[:short_name]
      puppetfile          = opts[:puppetfile]
      modulepath          = opts[:modulepath]
      local_fixtures_mods = opts[:local_fixtures_mods] || []

      fail('You must pass a short module name') unless short_name

      fixtures_hash = {
        'fixtures' => {
          'symlinks' => {
            short_name => '#{source_dir}'
          }
        }
      }

      local_modules = {}

      if modulepath
        unless File.directory?(modulepath)
          fail("Could not find a module directory at #{modulepath}")
        end

        # Grab all of the local modules and convert them into something
        # that can be turned into a Hash easily
        local_modules = Hash[Dir.glob(File.join(modulepath, '*', 'metadata.json')).map do |m|
          [File.basename(File.dirname(m)), File.absolute_path(File.dirname(m))]
        end]

        local_modules.delete(short_name)
      end

      if puppetfile
        fail("Could not find Puppetfile at #{puppetfile}") unless File.exist?(puppetfile)

        require 'simp/rake/build/deps'

        puppetfile = R10KHelper.new(puppetfile)

        puppetfile.modules.each do |pupmod|
          next unless pupmod[:name]
          next if pupmod[:status] == :unknown

          if local_modules[pupmod[:name]]
            unless local_fixtures_mods.empty?
              local_fixtures_mod = local_fixtures_mods.delete(pupmod[:name])
              next unless local_fixtures_mod
            end

            fixtures_hash['fixtures']['symlinks'][pupmod[:name]] = local_modules[pupmod[:name]]
          else
            fixtures_hash['fixtures']['repositories'] ||= {}

            unless local_fixtures_mods.empty?
              local_fixtures_mod = local_fixtures_mods.delete(pupmod[:name])
              next unless local_fixtures_mod
            end

            next unless pupmod[:remote] && pupmod[:desired_ref]
            next if pupmod[:name] == short_name

            fixtures_hash['fixtures']['repositories'][pupmod[:name]] = {
              'repo' => pupmod[:remote],
              'ref'  => pupmod[:desired_ref]
            }
          end
        end
      elsif modulepath
        local_modules.each_pair do |pupmod, path|
          unless local_fixtures_mods.empty?
            local_fixtures_mod = local_fixtures_mods.delete(pupmod)
            next unless local_fixtures_mod
          end

          fixtures_hash['fixtures']['symlinks'][pupmod] = path
        end
      end

      if local_fixtures_mods.empty?
        custom_fixtures_path = File.join('spec','fixtures','simp_rspec','fixtures.yml')
      else
        custom_fixtures_path = File.join('spec','fixtures','simp_rspec','fixtures_tmp.yml')
      end

      if puppetfile || modulepath
        FileUtils.mkdir_p(File.dirname(custom_fixtures_path))

        File.open(custom_fixtures_path, 'w') do |fh|
          fh.puts(fixtures_hash.sort_by_key(true).to_yaml)
        end
      end

      unless local_fixtures_mods.empty?
        errmsg = [
          '===',
          'The following modules in .fixtures.yml were not found in the Puppetfile:',
          %{  * #{local_fixtures_mods.join("\n  * ")}},
          %{A temporary fixtures file has been written to #{custom_fixtures_path}},
          '==='
        ]

        fail(errmsg.join("\n"))
      end

      return custom_fixtures_path
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
      quiet = true if args[:quiet].to_s == 'true'
      puts changelog_annotation( quiet )
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

      tags_source = args[:tags_source].nil? ? 'origin' : args[:tags_source]
      ignore_owner = true if args[:ignore_owner].to_s == 'true'
      verbose = true if args[:verbose].to_s == 'true'

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
          last_tag = (tags.sort { |a,b| Gem::Version.new(a) <=> Gem::Version.new(b) })[-1]

          # determine mission-impacting files that have changed
          files_changed = `git diff tags/#{last_tag} --name-only`.strip.split("\n")
          files_changed.delete_if do |file|
            file[0] ==  '.' or file =~ /^Gemfile/ or file == 'Rakefile' or file =~/^spec\// or file =~/^doc/
          end

          if files_changed.empty?
            puts "  No new tag required: No significant files have changed since '#{last_tag}' tag"
          else
            unless ignore_owner
              # determine latest version from CHANGELOG, which will present
              # for all SIMP Puppet modules
              line = IO.readlines('CHANGELOG')[0]
              match = line.match(/^\*\s+((?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{2} \d{4})\s+(.+<.+>)(?:\s+|\s*-\s*)?(\d+\.\d+\.\d+)/)
              unless match
                fail("ERROR: Invalid CHANGELOG entry. Unable to extract version from '#{line}'")
              end

              changelog_version = match[3]
              unless module_version == changelog_version
                fail("ERROR: Version mismatch.  module version=#{module_version}  changelog version=#{changelog_version}")
              end
            end

            curr_module_version = Gem::Version.new(module_version)
            last_tag_version = Gem::Version.new(last_tag)

            if curr_module_version < last_tag_version
              fail("ERROR: Version regression. '#{module_version}' < last tag '#{last_tag}'")
            elsif curr_module_version == last_tag_version
              fail("ERROR: Version update beyond last tag '#{last_tag}' is required for #{files_changed.count} changed files:\n  * #{files_changed.join("\n  * ")}")
            else
              puts "NOTICE: New tag of version '#{module_version}' is required for #{files_changed.count} changed files:\n  * #{files_changed.join("\n  * ")}"
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
      :metadata_lint,
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

    # This hidden task provides a way to create and use a fixtures.yml file
    # based on an externally specified Puppetfile
    #
    # The resulting fixtures.yml will contain only those modules that are
    # in the local fixtures.yml but with the version specified in the
    # Puppetfile.
    #
    # Downloaded repos that do not contain a metadata.json will be removed
    #
    # Set the environment variable SIMP_RSPEC_PUPPETFILE to point to a remote Puppetfile
    #
    # Set the environment variable SIMP_RSPEC_FIXTURES_OVERRIDE to 'yes' to
    # ignore the local fixtures.yml file.
    #
    # Set the environment variable SIMP_RSPEC_MODULEPATH to symlink named
    # modules from the designated directory instead of downloading them.
    #
    # If both SIMP_RSPEC_PUPPETFILE and SIMP_RSPEC_MODULEPATH are specified,
    # the Puppetfile will win.
    task :custom_fixtures_hook do
      # Don't do anything if the user has already set a path to their fixtures
      unless ENV['FIXTURES_YML']
        @custom_fixtures_hook_override_fixtures = (ENV.fetch('SIMP_RSPEC_FIXTURES_OVERRIDE', 'no') == 'yes')

        opts = { :short_name => metadata['name'].split('-').last }

        if ENV['SIMP_RSPEC_PUPPETFILE']
          opts[:puppetfile] = File.absolute_path(ENV['SIMP_RSPEC_PUPPETFILE'])
        end

        if ENV['SIMP_RSPEC_MODULEPATH']
          opts[:modulepath] = File.absolute_path(ENV['SIMP_RSPEC_MODULEPATH'])
        end

        if opts[:puppetfile] || opts[:modulepath]
          unless @custom_fixtures_hook_override_fixtures
            fail("Could not find '.fixtures.yml' at #{Dir.pwd}") unless File.exist?('.fixtures.yml')

            opts[:local_fixtures_mods] = []

            require 'yaml'
            _fixtures = YAML.load_file('.fixtures.yml')['fixtures']
            _fixtures.keys.each do |subset|
              _fixtures[subset].each_pair do |_mod, _extra|
                opts[:local_fixtures_mods] << _mod
              end
            end
          end

          fixtures_yml_path = custom_fixtures_hook(opts)

          if fixtures_yml_path
            ENV['FIXTURES_YML'] = fixtures_yml_path
          end
        end
      end
    end

    Rake::Task['spec_prep'].enhance [:custom_fixtures_hook] do
      Dir.glob(File.join('spec','fixtures','modules','*')).each do |dir|
        if @custom_fixtures_hook_override_fixtures
          FileUtils.remove_entry_secure(dir) unless File.exist?(File.join(dir, 'metadata.json'))
        end
      end
    end
  end
end
