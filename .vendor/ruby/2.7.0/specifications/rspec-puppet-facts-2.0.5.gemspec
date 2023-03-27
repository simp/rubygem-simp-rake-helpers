# -*- encoding: utf-8 -*-
# stub: rspec-puppet-facts 2.0.5 ruby lib

Gem::Specification.new do |s|
  s.name = "rspec-puppet-facts".freeze
  s.version = "2.0.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "2022-04-22"
  s.description = "Contains facts from many Facter version on many Operating Systems".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.homepage = "http://github.com/voxpupuli/rspec-puppet-facts".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.4.0".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Standard facts fixtures for Puppet".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<mime-types>.freeze, [">= 0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_development_dependency(%q<yard>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<puppet>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<facter>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<facterdb>.freeze, [">= 0.5.0"])
  else
    s.add_dependency(%q<mime-types>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_dependency(%q<yard>.freeze, [">= 0"])
    s.add_dependency(%q<puppet>.freeze, [">= 0"])
    s.add_dependency(%q<facter>.freeze, [">= 0"])
    s.add_dependency(%q<facterdb>.freeze, [">= 0.5.0"])
  end
end
