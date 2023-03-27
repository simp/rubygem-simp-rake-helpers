# -*- encoding: utf-8 -*-
# stub: facterdb 1.21.0 ruby lib

Gem::Specification.new do |s|
  s.name = "facterdb".freeze
  s.version = "1.21.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze]
  s.date = "2023-01-25"
  s.description = "Contains facts from many Facter version on many Operating Systems".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.executables = ["facterdb".freeze]
  s.files = ["bin/facterdb".freeze]
  s.homepage = "http://github.com/voxpupuli/facterdb".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "A Database of OS facts provided by Facter".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<coveralls>.freeze, [">= 0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<pry>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<facter>.freeze, ["< 5.0.0"])
    s.add_runtime_dependency(%q<jgrep>.freeze, [">= 0"])
  else
    s.add_dependency(%q<coveralls>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<pry>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_dependency(%q<facter>.freeze, ["< 5.0.0"])
    s.add_dependency(%q<jgrep>.freeze, [">= 0"])
  end
end
