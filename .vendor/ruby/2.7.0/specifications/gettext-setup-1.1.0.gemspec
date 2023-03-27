# -*- encoding: utf-8 -*-
# stub: gettext-setup 1.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "gettext-setup".freeze
  s.version = "1.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Puppet".freeze]
  s.date = "2022-10-25"
  s.description = "A gem to ease i18n".freeze
  s.email = ["info@puppet.com".freeze]
  s.homepage = "https://github.com/puppetlabs/gettext-setup-gem".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "A gem to ease internationalization with fast_gettext".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<fast_gettext>.freeze, ["~> 2.1"])
    s.add_runtime_dependency(%q<gettext>.freeze, ["~> 3.4"])
    s.add_runtime_dependency(%q<locale>.freeze, [">= 0"])
    s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.1"])
    s.add_development_dependency(%q<rspec-core>.freeze, ["~> 3.1"])
    s.add_development_dependency(%q<rspec-expectations>.freeze, ["~> 3.1"])
    s.add_development_dependency(%q<rspec-mocks>.freeze, ["~> 3.1"])
    s.add_development_dependency(%q<rubocop>.freeze, [">= 0"])
    s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
  else
    s.add_dependency(%q<fast_gettext>.freeze, ["~> 2.1"])
    s.add_dependency(%q<gettext>.freeze, ["~> 3.4"])
    s.add_dependency(%q<locale>.freeze, [">= 0"])
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.1"])
    s.add_dependency(%q<rspec-core>.freeze, ["~> 3.1"])
    s.add_dependency(%q<rspec-expectations>.freeze, ["~> 3.1"])
    s.add_dependency(%q<rspec-mocks>.freeze, ["~> 3.1"])
    s.add_dependency(%q<rubocop>.freeze, [">= 0"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
  end
end
