require 'date'
require File.expand_path('lib/simp/rake/helpers/version.rb', File.dirname(__FILE__))

Gem::Specification.new do |s|
  s.name        = 'simp-rake-helpers'
  s.date        = Date.today.to_s
  s.summary     = "SIMP rake helpers"
  s.description = <<-EOF
    "simp-rake-helpers provides common methods for SIMP Rake Tasks"
  EOF
  s.version     = Simp::Rake::Helpers::VERSION
  s.email       = 'simp@simp-project.org'
  s.homepage    = 'https://github.com/simp/rubygem-simp-rake-helpers'
  s.license     = 'Apache-2.0'
  s.authors     = [
    "Chris Tessmer",
    "Trevor Vaughan"
  ]
  s.metadata = {
                 'issue_tracker' => 'https://simp-project.atlassian.net'
               }
  # gem dependencies
  #   for the published gem
  # ensure the gem is built out of versioned files

  s.add_runtime_dependency 'bundler',                   '~> 1.14'
  s.add_runtime_dependency 'rake',                      '>= 10.0', '< 13.0'
  s.add_runtime_dependency 'coderay',                   '~> 1.0'
  s.add_runtime_dependency 'puppet',                    '>= 3.0', '< 6.0'
  s.add_runtime_dependency 'puppet-lint',               '>= 1.0', '< 3.0'
  s.add_runtime_dependency 'puppetlabs_spec_helper',    '~> 2.0'
  s.add_runtime_dependency 'parallel',                  '~> 1.0'
  s.add_runtime_dependency 'simp-rspec-puppet-facts',   '~> 2.0'
  s.add_runtime_dependency 'puppet-blacksmith',         '~> 3.3'
  s.add_runtime_dependency 'simp-beaker-helpers',       '~> 1.0'
  s.add_runtime_dependency 'parallel_tests',            '~> 2.4'
  s.add_runtime_dependency 'r10k',                      '~> 2.2'
  s.add_runtime_dependency 'pager'
  s.add_runtime_dependency 'rspec',                     '~> 3.0'
  s.add_runtime_dependency 'beaker',                    '~> 3.14'
  s.add_runtime_dependency 'beaker-rspec',              '~> 6.1'
  s.add_runtime_dependency 'rspec-core',                '~> 3.0'
  # Because guard...I hate guard
  s.add_runtime_dependency 'listen',                    '~> 3.0.6' # 3.1 requires ruby 2.2+

  # for development
  s.add_development_dependency 'pry',         '~> 0.0'
  s.add_development_dependency 'pry-doc',     '~> 0.0'
  s.add_development_dependency 'highline',    '~> 1.6', '> 1.6.1'  # 1.8 safe

  s.add_development_dependency 'guard',       '~> 2.0'
  s.add_development_dependency 'guard-shell', '~> 0.0'
  s.add_development_dependency 'guard-rspec', '~> 4.0'


  s.files = Dir[
                'Rakefile',
                'CHANGELOG*',
                'CONTRIBUTING*',
                'LICENSE*',
                'README*',
                '{bin,lib,spec}/**/*',
                'Gemfile',
                'Guardfile',
                '.gitignore',
                '.rspec',
                '.travis.yml',
               ] & `git ls-files -z .`.split("\0")
end
