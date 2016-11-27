require 'rake/tasklib'
require 'ruby-progressbar'
require 'rake/clean'

module Simp; end
module Simp::Rake; end
module Simp::Rake::Build; end
class Simp::Rake::Build::Helpers
  def initialize( dir = Dir.pwd )
    Dir[ File.join(File.dirname(__FILE__),'*.rb') ].each do |rake_file|
      next if rake_file == __FILE__
      require rake_file
    end
    Simp::Rake::Build::Auto.new( dir )
    Simp::Rake::Build::Build.new( dir )
    Simp::Rake::Build::Code.new( dir )
    Simp::Rake::Build::Deps.new( dir )
    Simp::Rake::Build::Iso.new( dir )
    Simp::Rake::Build::Pkg.new( dir )
    Simp::Rake::Build::Spec.new( dir )
    Simp::Rake::Build::Tar.new( dir )
    Simp::Rake::Build::Upload.new( dir )
    Simp::Rake::Build::Unpack.new( dir )
    Simp::Rake::Build::Clean.new( dir )
  end
end
