# -*- encoding: utf-8 -*-
# stub: beaker-puppet 1.29.0 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker-puppet".freeze
  s.version = "1.29.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "2022-11-02"
  s.description = "For use for the Beaker acceptance testing tool".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.executables = ["beaker-puppet".freeze]
  s.files = ["bin/beaker-puppet".freeze]
  s.homepage = "https://github.com/voxpupuli/beaker-puppet".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.4".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Beaker's Puppet DSL Extension Helpers!".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<rspec-its>.freeze, [">= 0"])
    s.add_development_dependency(%q<fakefs>.freeze, [">= 0.6", "< 2.0"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_development_dependency(%q<beaker-vmpooler>.freeze, [">= 0"])
    s.add_development_dependency(%q<yard>.freeze, [">= 0"])
    s.add_development_dependency(%q<thin>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<beaker>.freeze, ["~> 4.1"])
    s.add_runtime_dependency(%q<in-parallel>.freeze, ["~> 0.1"])
    s.add_runtime_dependency(%q<oga>.freeze, [">= 0"])
  else
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<rspec-its>.freeze, [">= 0"])
    s.add_dependency(%q<fakefs>.freeze, [">= 0.6", "< 2.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_dependency(%q<beaker-vmpooler>.freeze, [">= 0"])
    s.add_dependency(%q<yard>.freeze, [">= 0"])
    s.add_dependency(%q<thin>.freeze, [">= 0"])
    s.add_dependency(%q<beaker>.freeze, ["~> 4.1"])
    s.add_dependency(%q<in-parallel>.freeze, ["~> 0.1"])
    s.add_dependency(%q<oga>.freeze, [">= 0"])
  end
end
