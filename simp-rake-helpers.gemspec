Gem::Specification.new do |s|
  s.name        = 'simp-rake-helpers'
  s.date        = Date.today.to_s
  s.summary     = "SIMP rake helpers"
  s.description = <<-EOF
    "simp-rake-helpers provides common methods for SIMP Rake Tasks"
  EOF
  s.version     = '1.0.3'
  s.email       = 'simp@simp-project.org'
  s.homepage    = 'https://github.com/NationalSecurityAgency/rubygem-simp-rake-helpers'
  s.license     = 'Apache-2.0'
  s.authors     = [
    "Chris Tessmer",
    "Trevor Vaughan"
  ]
  s.metadata = {
                 'issue_tracker' => 'https://github.com/simp/rubygem-simp-rake-helpers/issues'
               }
  # gem dependencies
  #   for the published gem
  # ensure the gem is built out of versioned files
  s.add_runtime_dependency 'bundler'
  s.add_runtime_dependency 'rake'
  s.add_runtime_dependency 'coderay'
  s.add_runtime_dependency 'puppet'
  s.add_runtime_dependency 'puppet-lint'
  s.add_runtime_dependency 'puppetlabs_spec_helper'
  s.add_runtime_dependency 'puppet_module_spec_helper'

  # for development
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-doc'
  s.add_development_dependency 'highline'


  s.files = Dir['Rakefile', '{bin,lib,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z .`.split("\0")
end
