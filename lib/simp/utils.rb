module Simp; end

# Class containing miscellaneous utilities
class Simp::Utils

  # Add a standard method for cleaning up strange YAML translations between
  # versions of Ruby
  #
  # Assumes YAML string input
  def self.clean_yaml(yaml_input)
    yaml_output = yaml_input.dup

    # Had some issues with different versions of ruby giving different results
    yaml_output.gsub!(%r(!ruby/sym(bol)? ), ':')

    # Also, some versions appear to dump out trailing whitespace
    yaml_output.gsub!(/\s+$/, '')

    return yaml_output
  end


  # Copies specific content from one directory to another.
  # start_dir:: the root directory where the original files are located within
  # src:: a pattern given to find(1) to match against the desired files to copy
  # dest:: the destination directory to receive the copies
  def self.copy_wo_vcs(start_dir, src, dest, dereference=true)
    if dereference.nil? || dereference
      dereference = "--dereference"
    else
      dereference = ""
    end

    Dir.chdir(start_dir) do
      system(%{find #{src} \\( -path "*/.svn" -a -type d -o -path "*/.git*" \\) -prune -o -print | cpio -u --warning none --quiet --make-directories #{dereference} -p "#{dest}" 2>&1 > /dev/null})
    end
  end

  # Force the encoding to something that Ruby >= 1.9 is happy with
  def self.encode_line(line)
    if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('1.9')
      require 'iconv'
      line = Iconv.new('ISO-8859-1//IGNORE','UTF-8').iconv(line)
    else
      line = line.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8,:replace => nil,:undef => :replace)
    end
  end

  # Executes a command and returns a hash with the exit status,
  # stdout output and stderr output.
  #
  # +cmd+::     Command to be executed
  # +verbose+:: Whether to log debug details
  def self.execute(cmd, verbose)
    require 'securerandom'

    if verbose
      puts "== Executing:  #{cmd}"
    end

    outfile = File.join('/tmp', "#{ENV['USER']}_#{SecureRandom.hex}")
    errfile = File.join('/tmp', "#{ENV['USER']}_#{SecureRandom.hex}")
    pid = spawn(cmd, :out=>outfile, :err=>errfile)

    begin
      pid,status = Process.wait2(pid)
    rescue Errno::ECHILD
      # process exited before status could be determined
    end

    exit_status = status.nil? ? nil : status.exitstatus
    stdout = IO.read(outfile)
    stderr = IO.read(errfile)

    { :exit_status => exit_status, :stdout => stdout, :stderr => stderr }
  ensure
    if verbose
      puts "    -------- exit_status: #{exit_status}"
      puts "    -------- stdout ",''
      puts File.readlines(outfile).map{|x| "    #{x}"}.join
      puts '',"    -------- stderr ",''
      puts File.readlines(errfile).map{|x| "    #{x}"}.join
    end
    FileUtils.rm_f([outfile, errfile])
  end


  # @returns maximum number of CPUs to use for parallel processing;
  #   defaults to number of available processors -1
  def self.get_cpu_limit(available_cpus = -1)
    require 'parallel'

    cpus = Parallel.processor_count
    env_cpus = available_cpus

    env_cpus  = 1          if env_cpus == 0
    env_cpus += cpus       if env_cpus < 0
    # sanitize huge numbers
    env_cpus  = (cpus - 1) if env_cpus >= cpus
    env_cpus  = 1          if env_cpus < 0

    env_cpus
  end

  def self.indent(message, indent_length=2)
    message.split("\n").map {|line| ' '*indent_length + line }.join("\n")
  end


  # Originally snarfed from
  # http://stackoverflow.com/questions/2108727/which-in-ruby-checking-if-program-exists-in-path-from-ruby
  def self.which(cmd)
    require 'facter'

    command = Facter::Core::Execution.which(cmd)
    warn "Warning: Command '#{cmd}' not found on the system." unless command
    return command
  end

end
