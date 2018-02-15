module Simp; end
module Simp::Rake
  class Rubygem < ::Rake::TaskLib
    def initialize( package, rakefile_dir = File.pwd )
      @package      = package
      @rakefile_dir = rakefile_dir
      define
    end

    def define_clean_paths
      CLEAN.include "#{@package}-*.gem"
      CLEAN.include 'pkg'
      CLEAN.include 'dist'
      CLEAN.include 'spec/acceptance/files/testpackage/dist'
      Find.find( @rakefile_dir ) do |path|
        if File.directory? path
          CLEAN.include path if File.basename(path) == 'tmp'
        else
          Find.prune
        end
      end
    end

    def define
      define_clean_paths

      desc 'Ensure gemspec-safe permissions on all files'
      task :chmod do
        gemspec = File.expand_path( "#{@package}.gemspec", @rakefile_dir ).strip
        spec = Gem::Specification::load( gemspec )
        spec.files.each do |file|
          FileUtils.chmod 'go=r', file
        end
      end

      namespace :pkg do
        desc "build rubygem package for #{@package}"
        task :gem => :chmod do
          Dir.chdir @rakefile_dir
          Dir['*.gemspec'].each do |spec_file|
            cmd = %Q{SIMP_RPM_BUILD=#{ENV.fetch('SIMP_RPM_BUILD',1)} bundle exec gem build "#{spec_file}"}
            sh cmd
            FileUtils.mkdir_p 'dist'
            FileUtils.mv Dir.glob("#{@package}*.gem"), 'dist/'
          end
        end

        desc "build and install rubygem package for #{@package}"
        task :install_gem => [:clean, :gem] do
          Dir.chdir @rakefile_dir
          Dir.glob("dist/#{@package}*.gem") do |pkg|
            sh %Q{bundle exec gem install --no-ri --no-rdoc #{pkg}}
          end
        end
      end

      desc "Run acceptance tests"
      RSpec::Core::RakeTask.new(:acceptance) do |t|
        t.pattern = 'spec/acceptance'
      end

      desc "Run spec tests"
      RSpec::Core::RakeTask.new(:spec) do |t|
          t.rspec_opts = ['--color']
          t.exclude_pattern = '**/{acceptance,fixtures,files}/**/*_spec.rb'
          t.pattern = 'spec/lib/simp/**/*_spec.rb'
      end
    end
  end
end
