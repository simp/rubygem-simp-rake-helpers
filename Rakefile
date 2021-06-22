require "rubygems"
require 'rake/clean'
require 'find'
require 'rspec/core/rake_task'


@package='simp-rake-helpers'
@rakefile_dir=File.dirname(__FILE__)

require 'simp/rake/rubygem'
Simp::Rake::Rubygem.new(@package, @rakefile_dir)

require 'simp/rake/beaker'

Simp::Rake::Beaker.new(Dir.pwd)
