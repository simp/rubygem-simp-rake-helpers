# frozen_string_literal: true

# Initialize puppet for testing by loading the
# 'puppetlabs_spec_helper/puppet_spec_helper' library
require 'puppetlabs_spec_helper/puppet_spec_helper'

module PuppetlabsSpec
  module PuppetInternals
    # parser_scope is intended to return a Puppet::Parser::Scope
    # instance suitable for placing in a test harness with the intent of
    # testing parser functions from modules.
    def scope(parts = {})
      RSpec.deprecate('scope', replacement: 'rspec-puppet 2.2.0 provides a scope property')

      if %r{^2\.[67]}.match?(Puppet.version)
        # loadall should only be necessary prior to 3.x
        # Please note, loadall needs to happen first when creating a scope, otherwise
        # you might receive undefined method `function_*' errors
        Puppet::Parser::Functions.autoloader.loadall
      end

      scope_compiler = parts[:compiler] || compiler
      scope_parent = parts[:parent] || scope_compiler.topscope
      scope_resource = parts[:resource] || resource(type: :node, title: scope_compiler.node.name)

      scope = if %r{^2\.[67]}.match?(Puppet.version)
                Puppet::Parser::Scope.new(compiler: scope_compiler)
              else
                Puppet::Parser::Scope.new(scope_compiler)
              end

      scope.source = Puppet::Resource::Type.new(:node, 'foo')
      scope.parent = scope_parent
      scope
    end
    module_function :scope

    def resource(parts = {})
      resource_type = parts[:type] || :hostclass
      resource_name = parts[:name] || 'testing'
      Puppet::Resource::Type.new(resource_type, resource_name)
    end
    module_function :resource

    def compiler(parts = {})
      compiler_node = parts[:node] || node
      Puppet::Parser::Compiler.new(compiler_node)
    end
    module_function :compiler

    def node(parts = {})
      node_name = parts[:name] || 'testinghost'
      options = parts[:options] || {}
      node_environment = if Puppet.version.to_f >= 4.0
                           Puppet::Node::Environment.create(parts[:environment] || 'test', [])
                         else
                           Puppet::Node::Environment.new(parts[:environment] || 'test')
                         end
      options[:environment] = node_environment
      Puppet::Node.new(node_name, options)
    end
    module_function :node

    # Return a method instance for a given function.  This is primarily useful
    # for rspec-puppet
    def function_method(name, parts = {})
      scope = parts[:scope] || scope()
      # Ensure the method instance is defined by side-effect of checking if it
      # exists.  This is a hack, but at least it's a hidden hack and not an
      # exposed hack.
      return nil unless Puppet::Parser::Functions.function(name)

      scope.method("function_#{name}".intern)
    end
    module_function :function_method
  end
end
