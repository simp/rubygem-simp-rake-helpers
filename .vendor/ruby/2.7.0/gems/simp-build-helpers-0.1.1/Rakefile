# encoding: utf-8

require 'rubygems'

begin
  require 'bundler/setup'
rescue LoadError => e
  abort e.message
end

require 'rake'


require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

task :test    => :spec
task :default => :spec

require 'rubygems/package_task'
Gem::PackageTask.new(Gem::Specification.load('simp-build-helpers.gemspec')) do |pkg|
  pkg.need_tar = true
  pkg.need_zip = false
end

require 'yard'
YARD::Rake::YardocTask.new  
task :doc => :yard
