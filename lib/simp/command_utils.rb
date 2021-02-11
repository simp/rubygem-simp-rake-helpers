module Simp; end
module Simp::CommandUtils
  require 'facter'

  def which(cmd, fail=false)
    @which_cache ||= {}

    if @which_cache.has_key?(cmd)
      command = @which_cache[cmd]
    else
      command = Facter::Core::Execution.which(cmd)
      @which_cache[cmd] = command
    end

    msg = "Warning: Command #{cmd} not found on the system."

    ( fail ? raise(msg) : warn(msg) ) unless command

    command
  end
end
