# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'stringify-hash/version'

Gem::Specification.new do |s|
  s.name        = "stringify-hash"
  s.version     = StringifyHash::Version::STRING
  s.authors     = ["Puppetlabs", "anode"]
  s.email       = ["qe-team@puppetlabs.com", 'alice@puppetlabs.com']
  s.homepage    = "https://github.com/puppetlabs/stringify-hash"
  s.summary     = %q{A Ruby Hash that treats symbols and strings interchangeably!}
  s.description = %q{:test == "test"}
  s.license     = 'Apache2'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # Testing dependencies
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rake', '~> 10.1'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'pry', '~> 0.10'

  # Documentation dependencies
  s.add_development_dependency 'yard'
  s.add_development_dependency 'markdown'
  s.add_development_dependency 'thin'

end
