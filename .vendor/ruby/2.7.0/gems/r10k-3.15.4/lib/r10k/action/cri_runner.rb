require 'r10k/action/runner'

module R10K
  module Action

    # Adapt the Cri runner interface to the R10K::Action::Runner interface
    #
    # This class provides the necessary glue to translate behavior specific
    # to Cri and the CLI component in general to the interface agnostic runner
    # class.
    #
    # @api private
    class CriRunner

      def self.wrap(klass)
        new(klass)
      end

      def initialize(klass)
        @klass = klass
      end

      # Intercept any instatiations of klass
      #
      # Defining #new allows this object to proxy method calls on the wrapped
      # runner and decorate various methods. Doing so allows this class to
      # manage CLI specific behaviors and isolate the underlying code from
      # having to deal with those particularities
      #
      # @param opts [Hash]
      # @param argv [Array<String>]
      # @param _cmd [Cri::Command] The command that was invoked. This value
      #   is not used and is only present to adapt the Cri interface to r10k.
      # @return [self]
      def new(opts, argv, _cmd = nil)
        handle_opts(opts)
        handle_argv(argv)
        @runner = R10K::Action::Runner.new(@opts, @argv, @klass)
        self
      end

      # @return [Hash] The adapted options for the runner
      def handle_opts(opts)
        if opts[:verbose]
          # Translate from the Cri verbose logging option to the internal logging setting.
          opts[:loglevel] = opts.delete(:verbose)
        end

        # Colored logging is only appropriate for CLI interactions, so we
        # handle this while we're still in CLI specific code.
        use_color = opts.delete(:color)
        if use_color
          R10K::Logging.use_color = use_color
        end

        @opts = opts
      end

      # @return [Array] The adapted arguments for the runner
      def handle_argv(argv)
        @argv = argv
      end

      # Invoke the wrapped behavior, determine if it succeeded, and exit with
      # the resulting exit code.
      def call
        rv = @runner.call
        exit(rv ? 0 : 1)
      end
    end
  end
end
