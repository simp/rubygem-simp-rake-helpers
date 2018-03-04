require 'beaker-rspec'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers
require 'tmpdir'
require 'pry' if ENV['PRY'] == 'yes'

$LOAD_PATH.unshift(File.expand_path('../acceptance/support',__FILE__))

module Simp::BeakerHelpers::SimpRakeHelpers
  # Add RSpec log comments within examples ("it blocks")
  def comment(msg, indent=10)
    logger.optionally_color(Beaker::Logger::MAGENTA, " "*indent + msg)
  end

  # basic command + arguments for executing `runuser` within an SUT
  def run_cmd
    @run_cmd ||= 'runuser build_user -l -c '
  end
end

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
