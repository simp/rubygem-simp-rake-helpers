# Variables:
#
# SIMP_GEM_SERVERS | a space/comma delimited list of rubygem servers
# PUPPET_VERSION   | specifies the version of the puppet gem to load
puppetversion = ENV.key?('PUPPET_VERSION') ? "#{ENV['PUPPET_VERSION']}" : '~> 6'
gem_sources   = ENV.key?('SIMP_GEM_SERVERS') ? ENV['SIMP_GEM_SERVERS'].split(/[, ]+/) : ['https://rubygems.org']

gem_sources.each { |gem_source| source gem_source }

gemspec

gem 'simp-build-helpers'
#gem 'simp-beaker-helpers'
gem 'simp-beaker-helpers', :git => 'https://github.com/trevor-vaughan/rubygem-simp-beaker-helpers', :branch => 'SIMP-MAINT-fix_seds'
gem 'beaker-puppet_install_helper'
gem 'rake', '>= 12.3.3'
gem 'beaker-docker'

if puppetversion
  gem 'puppet', puppetversion
end

