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
gem 'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', '~> 3.0')
gem 'beaker_puppet_helpers'
gem 'rake', '>= 12.3.3'
gem 'beaker-docker'

gem 'openvox', openvox_version

group :test do
  # rubocop, rubocop-rake, and rubocop-rspec are pulled in and version-pinned by
  # voxpupuli-test; pinning them here conflicts with its constraints.
  # rubocop-performance is not a voxpupuli-test dependency, so it stays explicit.
  gem 'rubocop-performance', '~> 1.26.0'
end

