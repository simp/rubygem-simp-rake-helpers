require 'beaker-rspec'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers
require 'tmpdir'
require 'pry' if ENV['PRY'] == 'yes'

require 'acceptance/support/simp_rake_helpers'
$LOAD_PATH.unshift(File.expand_path('../acceptance/support',__FILE__))


RSpec.configure do |c|
  # provide helper methods to individual examples AND example groups
  c.include Simp::BeakerHelpers::SimpRakeHelpers
  c.extend Simp::BeakerHelpers::SimpRakeHelpers

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
  end
end
