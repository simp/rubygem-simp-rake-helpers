# -*- encoding: utf-8 -*-
# stub: in-parallel 0.1.17 ruby lib

Gem::Specification.new do |s|
  s.name = "in-parallel".freeze
  s.version = "0.1.17"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["samwoods1".freeze]
  s.date = "2017-02-07"
  s.description = "Many other Ruby libraries that simplify parallel execution support one primary use case - crunching through a large queue of small, similar tasks as quickly and efficiently as possible.  This library primarily supports the use case of executing a few larger and unrelated tasks in parallel, automatically managing the stdout and passing return values back to the main process. This library was created to be used by Puppet's Beaker test framework to enable parallel execution of some of the framework's tasks, and allow users to execute code in parallel within their tests.".freeze
  s.email = ["sam.woods@puppetlabs.com".freeze]
  s.homepage = "https://github.com/puppetlabs/in-parallel".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.6".freeze
  s.summary = "A lightweight library to execute a handful of tasks in parallel with simple syntax".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version
end
