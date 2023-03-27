# -*- encoding: utf-8 -*-
# stub: beaker-hostgenerator 1.18.1 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker-hostgenerator".freeze
  s.version = "1.18.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Branan Purvine-Riley".freeze, "Wayne Warren".freeze, "Nate Wolfe".freeze]
  s.date = "2022-12-14"
  s.description = "The beaker-hostgenerator tool will take a Beaker SUT (System Under Test) spec as\nits first positional argument and use that to generate a Beaker host\nconfiguration file.\n".freeze
  s.email = ["qe-team@puppet.com".freeze]
  s.executables = ["beaker-hostgenerator".freeze, "genconfig2".freeze]
  s.files = ["bin/beaker-hostgenerator".freeze, "bin/genconfig2".freeze]
  s.homepage = "https://github.com/puppetlabs/beaker-hostgenerator".freeze
  s.licenses = ["Apache2".freeze]
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Beaker Host Generator Utility".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<rspec-its>.freeze, [">= 0"])
    s.add_development_dependency(%q<fakefs>.freeze, [">= 0.6", "< 2.0"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_development_dependency(%q<pry>.freeze, ["~> 0.10"])
    s.add_development_dependency(%q<yard>.freeze, [">= 0"])
    s.add_development_dependency(%q<thin>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<deep_merge>.freeze, ["~> 1.0"])
  else
    s.add_dependency(%q<minitest>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<rspec-its>.freeze, [">= 0"])
    s.add_dependency(%q<fakefs>.freeze, [">= 0.6", "< 2.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_dependency(%q<pry>.freeze, ["~> 0.10"])
    s.add_dependency(%q<yard>.freeze, [">= 0"])
    s.add_dependency(%q<thin>.freeze, [">= 0"])
    s.add_dependency(%q<deep_merge>.freeze, ["~> 1.0"])
  end
end
