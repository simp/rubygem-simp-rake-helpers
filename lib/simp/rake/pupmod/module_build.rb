# frozen_string_literal: true

require 'rake'
require 'puppet/modulebuilder'

module Simp
  module Rake
    module Pupmod
      # Extends Puppet::Modulebuilder::Builder to honour .pdkignore files.
      # puppet-modulebuilder 2.x dropped native .pdkignore support; this
      # restores it so the published tarball matches what PDK produced.
      class PdkCompatBuilder < Puppet::Modulebuilder::Builder
        def ignored_files
          spec = super
          pdkignore = File.join(source, '.pdkignore')
          return spec unless File.exist?(pdkignore)

          ignore = PathSpec.from_filename(pdkignore)
          ignore.add('.*') # Ignore dotfiles by default
          ignore
        end
      end
    end
  end
end

# Make the Rake DSL (namespace/desc/task) available so this file can be required
# directly (e.g. from RSpec), not only from within a Rakefile where the DSL is
# already mixed into the top-level scope.
extend Rake::DSL

namespace :pupmod do
  desc 'Build the Puppet module package into pkg/, honouring .pdkignore'
  task :build do
    builder = Simp::Rake::Pupmod::PdkCompatBuilder.new(Dir.pwd)
    pkg = builder.build
    puts "Built: #{pkg}"
  end
end
