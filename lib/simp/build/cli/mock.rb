require 'thor'
require 'simp/build/mock'

module Simp::Build::CLI; end
class Simp::Build::CLI::Mock < Thor

  desc '`init ROOT [UNIQUEEXT]`'
       'record packages information for this release'
  def record(path=Dir.pwd, outfile=nil)
    packages.record(path,outfile)
  end

  desc '`list FILE`', 'list packages in ISO packages file'
  long_desc <<-EOF
  `list` will list all packages from an archive YAML file.
  EOF
  def list
    raise NotImplementedError, 'TODO list file!'
  end
end
