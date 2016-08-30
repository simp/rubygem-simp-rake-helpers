require 'simp'
require File.expand_path('pkg', File.dirname(__FILE__))
require File.expand_path('fixtures', File.dirname(__FILE__))

module Simp; end
module Simp::Rake; end
class Simp::Rake::Helpers
  attr_reader :log

  # dir = top-level of project,
  def initialize( dir = Dir.pwd )
    @log = Logging.logger[self]

    Simp::Rake::Pkg.new( dir ) do | t |
      t.clean_list << "#{t.base_dir}/spec/fixtures/hieradata/hiera.yaml"
    end

    Simp::Rake::Fixtures.new( dir )
  end

end
