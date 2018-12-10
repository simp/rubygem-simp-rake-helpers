module Simp; end
module Simp::Rake
  require 'rubygems'
  require 'erb'
  require 'rake/clean'
  require 'find'
  require 'yaml'
  require 'shellwords'
  require 'parallel'
  require 'tempfile'
  require 'facter'
  require 'simp/rake/pkg'
  require 'simp/utils'

  attr_reader(:puppetfile)
  attr_reader(:module_paths)

  def load_puppetfile(method='tracking')
    unless @puppetfile

      # Pull the puppetfile from the top-level
      @puppetfile = R10KHelper.new("#{@base_dir}/Puppetfile.#{method}")
      @module_paths = []

      @puppetfile.each_module do |mod|
        path = mod[:path]
        @module_paths.push(path)
      end
    end
  end

  # by default, we use all processors - 1
  # FIXME  This is used by simp-core
  def get_cpu_limit
    $stderr.puts 'get_cpu_limit is deprecated.  Please use Simp::Utils.get_cpu_limit'
    cpu_limit = ENV.fetch( 'SIMP_RAKE_LIMIT_CPUS', '-1' ).strip.to_i
    Simp::Utils.get_cpu_limit(cpu_limit)
  end

  # Snarfed from http://nex-3.com/posts/73-git-style-automatic-paging-in-ruby
  def run_pager
    return if RUBY_PLATFORM =~ /win32/
    return unless STDOUT.tty?

    read, write = IO.pipe

    unless Kernel.fork # Child process
      STDOUT.reopen(write)
      STDERR.reopen(write) if STDERR.tty?
      read.close
      write.close
      return
    end

    # Parent process, become pager
    STDIN.reopen(read)
    read.close
    write.close

    ENV['LESS'] = 'FSRX' # Don't page if the input is short enough

    Kernel.select [STDIN] # Wait until we have input before we start the pager
    pager = ENV['PAGER'] || 'less'
    exec pager rescue exec "/bin/sh", "-c", pager
  end
end
