require File.expand_path('lib/simp/rake/helpers.rb', File.dirname(__FILE__))

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
                 'issue_tracker' => ' https://github.com/simp/rubygem-simp-rake-helpers'
               }
  # gem dependencies
  #   for the published gem
  # ensure the gem is built out of versioned files
  s.add_runtime_dependency 'bundler',                   '~> 1'
  s.add_runtime_dependency 'rake',                      '~> 10'
  s.add_runtime_dependency 'coderay',                   '~> 1'
  s.add_runtime_dependency 'puppet',                    '>= 3'
  s.add_runtime_dependency 'puppet-lint',               '~> 1'
  s.add_runtime_dependency 'puppetlabs_spec_helper',    '~> 0'
  s.add_runtime_dependency 'parallel',                  '~> 1'

  # for development
  s.add_development_dependency 'gitlog-md',   '~> 0' # To generate HISTORY.md
  s.add_development_dependency 'pry',         '~> 0'
  s.add_development_dependency 'pry-doc',     '~> 0'
  s.add_development_dependency 'highline',    '~> 1.6', '> 1.6.1'  # 1.8 safe
  s.add_development_dependency 'rspec',       '~> 3'

  s.add_development_dependency 'guard',       '~> 2'
  s.add_development_dependency 'guard-shell', '~> 0'
  s.add_development_dependency 'guard-rspec', '~> 4'


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
