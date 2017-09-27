require File.expand_path('pkg', File.dirname(__FILE__))
require File.expand_path('fixtures', File.dirname(__FILE__))

module Simp; end
module Simp::Rake; end
class Simp::Rake::Helpers

  # dir = top-level of project,
  def initialize( dir = Dir.pwd )
    Simp::Rake::Pkg.new( dir ) do | t |
      t.clean_list << "#{t.base_dir}/spec/fixtures/hieradata/hiera.yaml"
    end

    Simp::Rake::Fixtures.new( dir )
  end

  def self.check_required_commands(required_commands)
    require 'facter'

    invalid_commands = Array.new

    Array(required_commands).each do |command|
      unless Facter::Core::Execution.which(command)
        invalid_commands << command
      end
    end

    unless invalid_commands.empty?
      errmsg = <<-EOM
Error: The following required commands were not found on your system:

  * #{invalid_commands.join("\n  * ")}

Please update your system and try again.
      EOM

      raise(errmsg)
    end
  end
end
