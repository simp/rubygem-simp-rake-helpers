# -*- encoding: utf-8 -*-
# stub: simp-beaker-helpers 1.28.0 ruby lib

Gem::Specification.new do |s|
  s.name = "simp-beaker-helpers".freeze
  s.version = "1.28.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "issue_tracker" => "https://simp-project.atlassian.net" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Chris Tessmer".freeze, "Trevor Vaughan".freeze]
  s.date = "2022-08-05"
  s.description = "    Beaker helper methods to help scaffold SIMP acceptance tests\n".freeze
  s.email = "simp@simp-project.org".freeze
  s.homepage = "https://github.com/simp/rubygem-simp-beaker-helpers".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.0".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "beaker helper methods for SIMP".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<beaker>.freeze, [">= 4.17.0", "< 5.0.0"])
    s.add_runtime_dependency(%q<beaker-rspec>.freeze, ["~> 7.1"])
    s.add_runtime_dependency(%q<beaker-puppet>.freeze, [">= 1.18.14", "< 2.0.0"])
    s.add_runtime_dependency(%q<beaker-docker>.freeze, [">= 0.8.3", "< 2.0.0"])
    s.add_runtime_dependency(%q<docker-api>.freeze, [">= 2.1.0", "< 3.0.0"])
    s.add_runtime_dependency(%q<beaker-vagrant>.freeze, [">= 0.6.4", "< 2.0.0"])
    s.add_runtime_dependency(%q<highline>.freeze, ["~> 2.0"])
    s.add_runtime_dependency(%q<nokogiri>.freeze, ["~> 1.8"])
  else
    s.add_dependency(%q<beaker>.freeze, [">= 4.17.0", "< 5.0.0"])
    s.add_dependency(%q<beaker-rspec>.freeze, ["~> 7.1"])
    s.add_dependency(%q<beaker-puppet>.freeze, [">= 1.18.14", "< 2.0.0"])
    s.add_dependency(%q<beaker-docker>.freeze, [">= 0.8.3", "< 2.0.0"])
    s.add_dependency(%q<docker-api>.freeze, [">= 2.1.0", "< 3.0.0"])
    s.add_dependency(%q<beaker-vagrant>.freeze, [">= 0.6.4", "< 2.0.0"])
    s.add_dependency(%q<highline>.freeze, ["~> 2.0"])
    s.add_dependency(%q<nokogiri>.freeze, ["~> 1.8"])
  end
end
