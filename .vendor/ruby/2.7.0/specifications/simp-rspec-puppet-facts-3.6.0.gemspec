# -*- encoding: utf-8 -*-
# stub: simp-rspec-puppet-facts 3.6.0 ruby lib

Gem::Specification.new do |s|
  s.name = "simp-rspec-puppet-facts".freeze
  s.version = "3.6.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Chris Tessmer".freeze, "Micka\u00EBl Can\u00E9vet".freeze]
  s.date = "2023-03-23"
  s.description = "shim that injects SIMP-related facts into rspec-puppet-facts".freeze
  s.email = "simp@simp-project.org".freeze
  s.homepage = "https://github.com/simp/rubygem-simp-rspec-puppet-facts".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.requirements = ["rspec-puppet-facts".freeze]
  s.rubygems_version = "3.1.6".freeze
  s.summary = "standard SIMP facts fixtures for Puppet".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<rspec-puppet-facts>.freeze, [">= 0"])
    s.add_development_dependency(%q<puppetlabs_spec_helper>.freeze, [">= 0"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 10"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.2"])
    s.add_runtime_dependency(%q<json>.freeze, [">= 1.0"])
    s.add_runtime_dependency(%q<facter>.freeze, [">= 2.5.0", "< 5.0"])
    s.add_development_dependency(%q<pry>.freeze, [">= 0"])
    s.add_development_dependency(%q<tins>.freeze, [">= 1.6"])
  else
    s.add_dependency(%q<rspec-puppet-facts>.freeze, [">= 0"])
    s.add_dependency(%q<puppetlabs_spec_helper>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, ["~> 10"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.2"])
    s.add_dependency(%q<json>.freeze, [">= 1.0"])
    s.add_dependency(%q<facter>.freeze, [">= 2.5.0", "< 5.0"])
    s.add_dependency(%q<pry>.freeze, [">= 0"])
    s.add_dependency(%q<tins>.freeze, [">= 1.6"])
  end
end
