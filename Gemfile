# Variables:
#
# SIMP_GEM_SERVERS | a space/comma delimited list of rubygem servers
# PUPPET_VERSION   | specifies the version of the puppet/openvox gems to load
# OPENVOX_VERSION  | overrides the openvox gem version (defaults to PUPPET_VERSION)
puppet_version  = ENV.fetch('PUPPET_VERSION', ['>= 8', '< 9'])
openvox_version = ENV.fetch('OPENVOX_VERSION', puppet_version)
gem_sources     = ENV.key?('SIMP_GEM_SERVERS') ? ENV['SIMP_GEM_SERVERS'].split(/[, ]+/) : ['https://rubygems.org']

gem_sources.each { |gem_source| source gem_source }

gemspec

gem 'simp-build-helpers'
# renovate: datasource=rubygems versioning=ruby
gem 'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', '~> 2.0.0')
gem 'beaker_puppet_helpers'
gem 'rake', '>= 12.3.3'
gem 'beaker-docker'

# Temporarily include both the openvox and puppet gems until the puppet
# dependency is removed from the rest of the gem dependency chain.
['openvox', 'puppet'].each do |gem_name|
  gem gem_name, binding.local_variable_get(:"#{gem_name}_version")
end

group :test do
  gem 'rubocop',             '~> 1.88.0'
  gem 'rubocop-performance', '~> 1.26.0'
  gem 'rubocop-rake',        '~> 0.7.0'
  gem 'rubocop-rspec',       '~> 3.10.0'
end

