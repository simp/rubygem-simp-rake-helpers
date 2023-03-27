# -*- encoding: utf-8 -*-
# stub: puppet-lint-optional_default-check 1.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet-lint-optional_default-check".freeze
  s.version = "1.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "2022-11-29"
  s.description = "    A puppet-lint plugin to check that Optional class/defined type parameters don't default to anything other than `undef`.\n".freeze
  s.email = "voxpupuli@groups.io".freeze
  s.homepage = "https://github.com/voxpupuli/puppet-lint-optional_default-check".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.4.0".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "A puppet-lint plugin to check Optional parameters default to `undef`".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<puppet-lint>.freeze, [">= 2.1", "< 4"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<rspec-its>.freeze, ["~> 1.0"])
    s.add_development_dependency(%q<rspec-collection_matchers>.freeze, ["~> 1.0"])
    s.add_development_dependency(%q<rspec-json_expectations>.freeze, [">= 0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
  else
    s.add_dependency(%q<puppet-lint>.freeze, [">= 2.1", "< 4"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<rspec-its>.freeze, ["~> 1.0"])
    s.add_dependency(%q<rspec-collection_matchers>.freeze, ["~> 1.0"])
    s.add_dependency(%q<rspec-json_expectations>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
  end
end
