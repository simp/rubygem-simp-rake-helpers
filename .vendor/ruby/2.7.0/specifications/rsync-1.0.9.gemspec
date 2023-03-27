# -*- encoding: utf-8 -*-
# stub: rsync 1.0.9 ruby lib

Gem::Specification.new do |s|
  s.name = "rsync".freeze
  s.version = "1.0.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Joshua Bussdieker".freeze]
  s.date = "2014-10-01"
  s.email = ["jbussdieker@gmail.com".freeze]
  s.homepage = "http://github.com/jbussdieker/ruby-rsync".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Ruby/Rsync is a Ruby library that can syncronize files between remote hosts by wrapping a call to the rsync binary.".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<bundler>.freeze, ["~> 1.3"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
  else
    s.add_dependency(%q<bundler>.freeze, ["~> 1.3"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
  end
end
