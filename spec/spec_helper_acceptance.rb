require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

require 'acceptance/support/simp_rake_helpers'
$LOAD_PATH.unshift(File.expand_path('../acceptance/support',__FILE__))

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Puppet
    if host.is_pe?
      install_pe
    else
      install_puppet
    end
  end
end


RSpec.configure do |c|
  # provide helper methods to individual examples AND example groups
  c.include Simp::BeakerHelpers::SimpRakeHelpers
  c.extend Simp::BeakerHelpers::SimpRakeHelpers

  # ensure that environment OS is ready on each host
  fix_errata_on hosts

  # Detect cases in which no examples are executed (e.g., nodeset does not
  # have hosts with required roles)
  c.fail_if_no_examples = true

  # Readable test descriptions
  c.formatter = :documentation

  c.before :suite do
  end
end
