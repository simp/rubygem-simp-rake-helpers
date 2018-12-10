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

  def initialize( base_dir = Dir.pwd )
    @base_dir = base_dir
    @temp_fixtures_path = File.join(base_dir,'spec','fixtures','simp_rspec')

    FileUtils.mkdir_p(@temp_fixtures_path)

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
      t.clean_list << "#{@base_dir}/spec/fixtures/hieradata/hiera.yaml"
      t.clean_list << @temp_fixtures_path
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
        custom_fixtures_path = File.join(@temp_fixtures_path, 'fixtures.yml')
      else
        custom_fixtures_path = File.join(@temp_fixtures_path, 'fixtures_tmp.yml')
      end

      if puppetfile || modulepath
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
          puppetfile = ENV['SIMP_RSPEC_PUPPETFILE']

          puppetfile_tgt = File.join(@temp_fixtures_path, 'Puppetfile')

          if puppetfile =~ %r{://}
            %x{curl -k -s -o #{puppetfile_tgt} #{puppetfile}}
          else
            FileUtils.cp(File.absolute_path(puppetfile), puppetfile_tgt)
          end

          opts[:puppetfile] = puppetfile_tgt
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
