# -*- encoding: utf-8 -*-
# stub: beaker 4.39.0 ruby lib

Gem::Specification.new do |s|
  s.name = "beaker".freeze
  s.version = "4.39.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Puppet".freeze]
  s.date = "2023-02-18"
  s.description = "Puppet's accceptance testing harness".freeze
  s.email = ["voxpupuli@groups.io".freeze]
  s.executables = ["beaker".freeze]
  s.files = ["bin/beaker".freeze]
  s.homepage = "https://github.com/voxpupuli/beaker".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.4".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Let's test Puppet!".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<fakefs>.freeze, ["~> 1.0"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_development_dependency(%q<rspec-its>.freeze, [">= 0"])
    s.add_development_dependency(%q<yard>.freeze, ["~> 0.9.11"])
    s.add_runtime_dependency(%q<minitar>.freeze, ["~> 0.6"])
    s.add_runtime_dependency(%q<minitest>.freeze, ["~> 5.4"])
    s.add_runtime_dependency(%q<rexml>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<ed25519>.freeze, ["~> 1.0"])
    s.add_runtime_dependency(%q<hocon>.freeze, ["~> 1.0"])
    s.add_runtime_dependency(%q<inifile>.freeze, ["~> 3.0"])
    s.add_runtime_dependency(%q<net-scp>.freeze, [">= 1.2", "< 5.0"])
    s.add_runtime_dependency(%q<net-ssh>.freeze, [">= 5.0"])
    s.add_runtime_dependency(%q<in-parallel>.freeze, ["~> 0.1"])
    s.add_runtime_dependency(%q<open_uri_redirections>.freeze, ["~> 0.2.1"])
    s.add_runtime_dependency(%q<rsync>.freeze, ["~> 1.0.9"])
    s.add_runtime_dependency(%q<thor>.freeze, [">= 1.0.1", "< 2.0"])
    s.add_runtime_dependency(%q<beaker-hostgenerator>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<stringify-hash>.freeze, ["~> 0.0"])
  else
    s.add_dependency(%q<fakefs>.freeze, ["~> 1.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<rspec-its>.freeze, [">= 0"])
    s.add_dependency(%q<yard>.freeze, ["~> 0.9.11"])
    s.add_dependency(%q<minitar>.freeze, ["~> 0.6"])
    s.add_dependency(%q<minitest>.freeze, ["~> 5.4"])
    s.add_dependency(%q<rexml>.freeze, [">= 0"])
    s.add_dependency(%q<ed25519>.freeze, ["~> 1.0"])
    s.add_dependency(%q<hocon>.freeze, ["~> 1.0"])
    s.add_dependency(%q<inifile>.freeze, ["~> 3.0"])
    s.add_dependency(%q<net-scp>.freeze, [">= 1.2", "< 5.0"])
    s.add_dependency(%q<net-ssh>.freeze, [">= 5.0"])
    s.add_dependency(%q<in-parallel>.freeze, ["~> 0.1"])
    s.add_dependency(%q<open_uri_redirections>.freeze, ["~> 0.2.1"])
    s.add_dependency(%q<rsync>.freeze, ["~> 1.0.9"])
    s.add_dependency(%q<thor>.freeze, [">= 1.0.1", "< 2.0"])
    s.add_dependency(%q<beaker-hostgenerator>.freeze, [">= 0"])
    s.add_dependency(%q<stringify-hash>.freeze, ["~> 0.0"])
  end
end
