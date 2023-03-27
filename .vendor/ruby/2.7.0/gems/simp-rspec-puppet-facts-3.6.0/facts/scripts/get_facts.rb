require 'puppet'
require 'json'
require 'facter'

ENV.fetch('FACTERLIB').split(':').each{|x| Facter.search x }

Puppet.initialize_settings
Facter.loadfacts

data = Facter.collection.to_hash
facter_major_ver = Facter.version.split('.').first
if ['1','2'].include? facter_major_ver
  facts = data
elsif ['1','2'].include? facter_major_ver
  facts = data['values']
end
jj JSON.parse facts.to_json
