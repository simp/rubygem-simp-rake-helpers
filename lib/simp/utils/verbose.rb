module Simp
  module Utils
    module Verbose
      # Verbosity levels
      #
      # * `:verbose` = detailed output
      # * `:normal`  = normal output
      # * `:quiet`   = skip output
      # * `:silent`  = skip command && output
      VERBOSE_LEVELS = [:silent,:quiet,:normal,:verbose]

      # @!attribute [r]
      #   Verbosity level for this instance (uses {#VERBOSE_LEVELS})
      #   @return [Symbol] (default: `:normal`)
      attr_reader   :verbose

      @verbose       = :normal
    end
  end
end
