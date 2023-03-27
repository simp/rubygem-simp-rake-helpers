# -*- encoding: utf-8 -*-
# stub: simp-build-helpers 0.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "simp-build-helpers".freeze
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Chris Tessmer".freeze]
  s.date = "2016-09-28"
  s.description = "Provides helper methods for building SIMP".freeze
  s.email = "simp@simp-project.org".freeze
  s.homepage = "https://github.com/simp/rubygem-simp-build-helpers".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.rubygems_version = "3.1.6".freeze
  s.summary = "SIMP build helpers".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<bundler>.freeze, ["~> 1.0"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 10.0"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<yard>.freeze, ["~> 0.8"])
  else
    s.add_dependency(%q<bundler>.freeze, ["~> 1.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 10.0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<yard>.freeze, ["~> 0.8"])
  end
end
