require 'r10k/action/base'
require 'r10k/action/deploy/deploy_helpers'
require 'r10k/deployment'

module R10K
  module Action
    module Deploy
      class Display < R10K::Action::Base

        include R10K::Action::Deploy::DeployHelpers

        # @param opts [Hash] A hash of options defined in #allowed_initialized_opts
        #   and managed by the SetOps mixin within the Action::Base class.
        #   Corresponds to the CLI flags and options.
        # @param argv [Enumerable] Typically CRI::ArgumentList or Array. A list-like
        #   collection of the remaining arguments to the CLI invocation (after
        #   removing flags and options).
        # @param settings [Hash] A hash of configuration loaded from the relevant
        #   config (r10k.yaml).
        #
        # @note All arguments will be required in the next major version
        def initialize(opts, argv, settings = {})
          super

          @settings = @settings.merge({
            overrides: {
              environments: {
                preload_environments: @fetch,
                requested_environments: @argv.map { |arg| arg.gsub(/\W/, '_') }
              },
              modules: {},
              output: {
                format: @format,
                trace: @trace,
                detail: @detail
              },
              purging: {}
            }
          })
        end

        def call
          expect_config!
          deployment = R10K::Deployment.new(@settings)

          if @settings.dig(:overrides, :environments, :preload_environments)
            deployment.preload!
            deployment.validate!
          end

          output = { :sources => deployment.sources.map { |source| source_info(source, @settings.dig(:overrides, :environments, :requested_environments)) } }

          case @settings.dig(:overrides, :output, :format)
          when 'json' then json_format(output)
          else yaml_format(output)
          end

          # exit 0
          true
        rescue => e
          logger.error R10K::Errors::Formatting.format_exception(e, @settings.dig(:overrides, :output, :trace))
          false
        end

        private

        def json_format(output)
          require 'json'
          puts JSON.pretty_generate(output)
        end

        def yaml_format(output)
          require 'yaml'
          puts output.to_yaml
        end

        def source_info(source, requested_environments = [])
          source_info = {
            :name => source.name,
            :basedir => source.basedir,
          }

          source_info[:prefix] = source.prefix if source.prefix
          source_info[:remote] = source.remote if source.respond_to?(:remote)

          select_all_envs = requested_environments.empty?
          env_list = source.environments.select { |env| select_all_envs || requested_environments.include?(env.name) }
          source_info[:environments] = env_list.map { |env| environment_info(env) }

          source_info
        end

        def environment_info(env)
          modules = @settings.dig(:overrides, :environments, :deploy_modules)
          if !modules && !@settings.dig(:overrides, :output, :detail)
            env.dirname
          else
            env_info = env.info.merge({
              :status => (env.status rescue nil),
            })

            env_info[:modules] = env.modules.map { |mod| module_info(mod) } if modules

            env_info
          end
        end

        def module_info(mod)
          if @settings.dig(:overrides, :output, :detail)
            { :name => mod.title, :properties => mod.properties }
          else
            mod.title
          end
        end

        def allowed_initialize_opts
          super.merge({
            puppetfile: :modules,
            modules: :self,
            detail: :self,
            format: :self,
            fetch: :self
          })
        end
      end
    end
  end
end
