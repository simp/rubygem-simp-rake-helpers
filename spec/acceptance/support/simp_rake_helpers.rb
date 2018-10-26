module Simp::BeakerHelpers::SimpRakeHelpers
  # Add RSpec log comments within examples ("it blocks")
  def comment(msg, indent = 10)
    logger.optionally_color(Beaker::Logger::MAGENTA, ' ' * indent + msg)
  end

  # basic command + arguments for executing `runuser` within an SUT
  def run_cmd
    @run_cmd ||= 'runuser build_user -l -c '
  end
end
