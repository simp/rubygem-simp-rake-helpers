# -*- encoding: utf-8 -*-
# stub: parallel_tests 2.24.0 ruby lib

Gem::Specification.new do |s|
  s.name = "parallel_tests".freeze
  s.version = "2.24.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Grosser".freeze]
  s.date = "2018-10-23"
  s.email = "michael@grosser.it".freeze
  s.executables = ["parallel_spinach".freeze, "parallel_cucumber".freeze, "parallel_rspec".freeze, "parallel_test".freeze]
  s.files = ["bin/parallel_cucumber".freeze, "bin/parallel_rspec".freeze, "bin/parallel_spinach".freeze, "bin/parallel_test".freeze]
  s.homepage = "http://github.com/grosser/parallel_tests".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.1.0".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Run Test::Unit / RSpec / Cucumber / Spinach in parallel".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<parallel>.freeze, [">= 0"])
  else
    s.add_dependency(%q<parallel>.freeze, [">= 0"])
  end
end
