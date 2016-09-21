require 'thor'
require 'simp/build/cli/mock'

module Simp; end
module Simp::Build; end

class Simp::Build::Cli < Thor
  desc 'mock COMMAND', 'Use mock'
  long_desc <<-EOF
    use mock to do build SIMP tarballs, SRPMs, and RPMs
  EOF
  subcommand 'mock', Simp::Build::CLI::Mock
end

if __FILE__ == $0
  Simp::Build::Cli.start( ARGV )
end

