require 'simp'
require 'logging'
require 'open3'

module Simp
  # Setup for the SIMP logger
  module Logger
    if ENV['LOG_LEVEL']
      log_threshold = ENV['LOG_LEVEL'].to_s.downcase
    else
      log_threshold = 'warn'
    end

    Dir.mkdir('log') unless Dir.exist?('log')

    Logging.logger.root.add_appenders(
      Logging.appenders.stderr(:level => log_threshold),
      Logging.appenders.file('log/output.log', :layout => Logging.layouts.json)
    )

    @log = Logging.logger['Simp']

    # A system command runner to capture output and pipe it to the logger.
    #
    # @param cmd  [String] The command string to execute.
    #
    # @return [Process::Waiter]
    #
    def log_run(cmd)
      _, stdout, stderr, wait_thread = Open3.popen3(cmd)

      out = stdout.read
      err = stderr.read

      @log.debug out.chomp unless out.empty?
      @log.error err.chomp unless err.empty?

      wait_thread
    end
  end
end
