# -*- encoding: utf-8 -*-
# stub: beaker-docker 1.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker-docker".freeze
  s.version = "1.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vox Pupuli".freeze, "Rishi Javia".freeze, "Kevin Imber".freeze, "Tony Vu".freeze]
  s.date = "2023-03-24"
  s.description = "Allows running Beaker tests using Docker".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.executables = ["beaker-docker".freeze]
  s.files = ["bin/beaker-docker".freeze]
  s.homepage = "https://github.com/voxpupuli/beaker-docker".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new([">= 2.4".freeze, "< 4".freeze])
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Docker hypervisor for Beaker acceptance testing framework".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<fakefs>.freeze, [">= 1.3", "< 3.0"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.12.0"])
    s.add_development_dependency(%q<rubocop-performance>.freeze, ["~> 1.10"])
    s.add_development_dependency(%q<rubocop-rake>.freeze, ["~> 0.2"])
    s.add_development_dependency(%q<rubocop-rspec>.freeze, [">= 1.44"])
    s.add_runtime_dependency(%q<beaker>.freeze, [">= 4.34"])
    s.add_runtime_dependency(%q<docker-api>.freeze, ["~> 2.1"])
    s.add_runtime_dependency(%q<stringify-hash>.freeze, ["~> 0.0.0"])
  else
    s.add_dependency(%q<fakefs>.freeze, [">= 1.3", "< 3.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<rubocop>.freeze, ["~> 1.12.0"])
    s.add_dependency(%q<rubocop-performance>.freeze, ["~> 1.10"])
    s.add_dependency(%q<rubocop-rake>.freeze, ["~> 0.2"])
    s.add_dependency(%q<rubocop-rspec>.freeze, [">= 1.44"])
    s.add_dependency(%q<beaker>.freeze, [">= 4.34"])
    s.add_dependency(%q<docker-api>.freeze, ["~> 2.1"])
    s.add_dependency(%q<stringify-hash>.freeze, ["~> 0.0.0"])
  end
end
