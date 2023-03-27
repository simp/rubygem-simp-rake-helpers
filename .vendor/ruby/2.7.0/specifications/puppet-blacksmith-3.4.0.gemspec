# -*- encoding: utf-8 -*-
# stub: puppet-blacksmith 3.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puppet-blacksmith".freeze
  s.version = "3.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["MaestroDev".freeze]
  s.date = "2016-07-11"
  s.description = "Puppet module tools for development and Puppet Forge management".freeze
  s.email = ["info@maestrodev.com".freeze]
  s.homepage = "http://github.com/maestrodev/puppet-blacksmith".freeze
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Tasks to manage Puppet module builds".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<rest-client>.freeze, ["~> 1.8.0"])
    s.add_runtime_dependency(%q<puppet>.freeze, [">= 2.7.16"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<puppetlabs_spec_helper>.freeze, [">= 0"])
    s.add_development_dependency(%q<cucumber>.freeze, [">= 0"])
    s.add_development_dependency(%q<aruba>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, [">= 3.0.0"])
    s.add_development_dependency(%q<webmock>.freeze, ["~> 1.23.0"])
  else
    s.add_dependency(%q<rest-client>.freeze, ["~> 1.8.0"])
    s.add_dependency(%q<puppet>.freeze, [">= 2.7.16"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<puppetlabs_spec_helper>.freeze, [">= 0"])
    s.add_dependency(%q<cucumber>.freeze, [">= 0"])
    s.add_dependency(%q<aruba>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 3.0.0"])
    s.add_dependency(%q<webmock>.freeze, ["~> 1.23.0"])
  end
end
