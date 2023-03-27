# -*- encoding: utf-8 -*-
# stub: beaker-vagrant 0.7.1 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker-vagrant".freeze
  s.version = "0.7.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Rishi Javia, Kevin Imber, Tony Vu".freeze]
  s.date = "2021-05-26"
  s.description = "For use for the Beaker acceptance testing tool".freeze
  s.email = ["rishi.javia@puppet.com, kevin.imber@puppet.com, tony.vu@puppet.com".freeze]
  s.executables = ["beaker-vagrant".freeze]
  s.files = ["bin/beaker-vagrant".freeze]
  s.homepage = "https://github.com/puppetlabs/beaker-vagrant".freeze
  s.licenses = ["Apache2".freeze]
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Beaker DSL Extension Helpers!".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<rspec-its>.freeze, [">= 0"])
    s.add_development_dependency(%q<fakefs>.freeze, [">= 0.6", "< 2.0"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_development_dependency(%q<pry>.freeze, ["~> 0.10"])
    s.add_development_dependency(%q<yard>.freeze, [">= 0"])
    s.add_development_dependency(%q<thin>.freeze, [">= 0"])
  else
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<rspec-its>.freeze, [">= 0"])
    s.add_dependency(%q<fakefs>.freeze, [">= 0.6", "< 2.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_dependency(%q<pry>.freeze, ["~> 0.10"])
    s.add_dependency(%q<yard>.freeze, [">= 0"])
    s.add_dependency(%q<thin>.freeze, [">= 0"])
  end
end
