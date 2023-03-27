# -*- encoding: utf-8 -*-
# stub: stringify-hash 0.0.2 ruby lib

Gem::Specification.new do |s|
  s.name = "stringify-hash".freeze
  s.version = "0.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Puppetlabs".freeze, "anode".freeze]
  s.date = "2015-07-17"
  s.description = ":test == \"test\"".freeze
  s.email = ["qe-team@puppetlabs.com".freeze, "alice@puppetlabs.com".freeze]
  s.homepage = "https://github.com/puppetlabs/stringify-hash".freeze
  s.licenses = ["Apache2".freeze]
  s.rubygems_version = "3.1.6".freeze
  s.summary = "A Ruby Hash that treats symbols and strings interchangeably!".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 10.1"])
    s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_development_dependency(%q<pry>.freeze, ["~> 0.10"])
    s.add_development_dependency(%q<yard>.freeze, [">= 0"])
    s.add_development_dependency(%q<markdown>.freeze, [">= 0"])
    s.add_development_dependency(%q<thin>.freeze, [">= 0"])
  else
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 10.1"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_dependency(%q<pry>.freeze, ["~> 0.10"])
    s.add_dependency(%q<yard>.freeze, [">= 0"])
    s.add_dependency(%q<markdown>.freeze, [">= 0"])
    s.add_dependency(%q<thin>.freeze, [">= 0"])
  end
end
