# -*- encoding: utf-8 -*-
# stub: beaker-rspec 7.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker-rspec".freeze
  s.version = "7.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "2022-01-14"
  s.description = "RSpec bindings for beaker, see https://github.com/voxpupuli/beaker".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.homepage = "https://github.com/voxpupuli/beaker-rspec".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 2.4.0".freeze, "< 4.0.0".freeze])
  s.rubygems_version = "3.1.6".freeze
  s.summary = "RSpec bindings for beaker".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<minitest>.freeze, ["~> 5.4"])
    s.add_development_dependency(%q<fakefs>.freeze, [">= 0.6", "< 2"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_development_dependency(%q<yard>.freeze, [">= 0"])
    s.add_development_dependency(%q<thin>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<beaker>.freeze, ["> 3.0"])
    s.add_runtime_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_runtime_dependency(%q<serverspec>.freeze, ["~> 2"])
    s.add_runtime_dependency(%q<specinfra>.freeze, ["~> 2"])
  else
    s.add_dependency(%q<minitest>.freeze, ["~> 5.4"])
    s.add_dependency(%q<fakefs>.freeze, [">= 0.6", "< 2"])
    s.add_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_dependency(%q<yard>.freeze, [">= 0"])
    s.add_dependency(%q<thin>.freeze, [">= 0"])
    s.add_dependency(%q<beaker>.freeze, ["> 3.0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<serverspec>.freeze, ["~> 2"])
    s.add_dependency(%q<specinfra>.freeze, ["~> 2"])
  end
end
