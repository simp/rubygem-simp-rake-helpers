require 'beaker-rspec'
require 'tmpdir'
###require 'simp/beaker_helpers'
###include Simp::BeakerHelpers

RSpec.configure do |c|
  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
  end
end
