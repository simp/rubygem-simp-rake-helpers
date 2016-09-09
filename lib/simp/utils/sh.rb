require 'simp/utils/verbose'

module Simp
  module Utils
    module Sh
      include Simp::Utils::Verbose

      # Execute a shell command
      #
      # This behaves more or less like Rake's `sh` method, but with hooks that
      # could be redirected for logging.
      #
      # `@verbose` (provided by `Simp::Utils::Verbose`) governs the default for `verbose`
      #
      # @param [Array] cmd Command to execute, split into Array elements (like `Kernel#spawn`)
      # @param [String] _verbose Verbosity level to govern screen-spew
      def sh(cmd, _verbose=nil)
        verbose = _verbose || @verbose

        # TODO: ATTN Logger fans, place your hooks here:
        out = :out
        err = :err

        if verbose == :silent || verbose == :quiet
          out = :close
          err = :close
        end
        puts "== #{cmd.join(' ')}" unless verbose == :silent

        pid = spawn(*cmd, :out => out, :err => err )
        begin
          _pid, status = Process.wait2(pid)
        rescue Errno::ECHILD
          # TODO: what's a better way to handle this?
          fail "ERROR: `#{cmd.join(' ')}` failed with Errno::ECHILD`"
        end

        return status
      end
    end
  end
end
