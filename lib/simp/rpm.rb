require 'securerandom'

module Simp
  # Simp::RPM represents a single package that is built and packaged by the Simp team.
  class Simp::RPM
    require 'expect'
    require 'pty'
    require 'rake'

    @@gpg_keys = Hash.new
    attr_reader :basename, :version, :release, :full_version, :name
    attr_reader :verbose, :packages, :signature, :arch, :package_name

    if Gem.loaded_specs['rake'].version >= Gem::Version.new('0.9')
      def self.sh(args)
        system args
      end
    end

    # Constructs a new Simp::RPM object. Requires the path to the spec file, or
    # RPM, from which information will be gathered.
    #
    # The following information will be retreived:
    # [basename] The name of the package (as it would be queried in yum)
    # [version] The version of the package
    # [release] The release version of the package
    #   * NOTE: If this is a 'spec' file, it will stop on the first '%'
    #           encountered!
    # [full_version] The full version of the package: [version]-[release]
    # [name] The full name of the package: [basename]-[full_version]
    # [packages] An Array of package names belonging to the spec file or RPM
    def initialize(rpm_source)
      info = Simp::RPM.get_info(rpm_source)

      @basename = info[:name]
      @version = info[:version]
      @release = info[:release]
      @full_version = info[:full_version]
      @name = "#{@basename}-#{@full_version}"
      @arch = info[:arch]
      @package_name = "#{@name}.#{@arch}.rpm"
      @verbose = false
      @packages = info[:packages]
      @signature = info[:signature]

      @@vercmp ||= %x(which rpmdev-vercmp).strip
      raise(Error, "Error: Could not find 'rpmdev-vercmp'. Please install and try again.") if @@vercmp.empty?
    end

    # Returns whether or not the current RPM is newer than the passed RPM
    def newer?(rpm)
      Simp::RPM.newer(@package_name, rpm) == @package_name
    end

    # Returns the name of the newer RPM
    #
    # Will simply return the second RPM name if the two are equal
    def self.newer(rpm1, rpm2)
      if rpm1.nil? || rpm1.empty?
        fail('You must pass at least one RPM')
      end

      return rpm1 if rpm2.nil? || rpm2.empty?

      unless rpm1.match(%r(\.rpm$)) && rpm2.match(%r(\.rpm$))
        fail("You must pass valid RPM names! Got: '#{rpm1}' and '#{rpm2}'")
      end

      %x(#{@@vercmp} #{rpm1} #{rpm2})

      status = $?.exitstatus

      case status
      when 0
        # Equal
        return rpm2
      when 11
        # RPM1 Newer
        return rpm1
      when 12
        # RPM2 Newer
        return rpm2
      else
        fail("Could not compare RPMs '#{rpm1}' and '#{rpm2}'")
      end
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
        sh %{find #{src} \\( -path "*/.svn" -a -type d -o -path "*/.git*" \\) -prune -o -print | cpio -u --warning none --quiet --make-directories #{dereference} -p "#{dest}" 2>&1 > /dev/null}
      end
    end

    # Executes a command and returns a hash with the exit status,
    # stdout output and stderr output.
    # cmd:: command to be executed
    def self.execute(cmd)
      #puts "Executing: [#{cmd}]"
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
      FileUtils.rm_f([outfile, errfile])
    end

    # Parses information, such as the version, from the given specfile or RPM
    # into a hash.
    def self.get_info(rpm_source)
      info = {
        :has_dist_tag => false,
        :packages => Array.new
      }

      rpm_cmd = %(rpm -q --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n' 2>/dev/null)

      rpm_signature_query = %(rpm -q --queryformat '%|DSAHEADER?{%{DSAHEADER:pgpsig}}:{%|RSAHEADER?{%{RSAHEADER:pgpsig}}:{%|SIGGPG?{%{SIGGPG:pgpsig}}:{%|SIGPGP?{%{SIGPGP:pgpsig}}:{(none)}|}|}|}|\n\')

      if File.readable?(rpm_source)
        if File.read(rpm_source).include?('%{?dist}')
          info[:has_dist_tag] = true
        end

        if rpm_source.split('.').last == 'rpm'
          results = execute("#{rpm_cmd} -p #{rpm_source}")

          signature = %x(#{rpm_signature_query} -p #{rpm_source} 2>/dev/null).strip

          unless signature.include?('none')
            info[:signature] = signature
          end
        else
          results = execute("#{rpm_cmd} --specfile #{rpm_source}")
        end

        if results[:exit_status] != 0
          require 'pry'
          binding.pry
          raise <<-EOE
#{indent('Error getting RPM info:', 2)}
#{indent(results[:stderr].strip, 5)}
#{indent("Run '#{rpm_cmd.gsub("\n",'\\n')} --specfile #{rpm_source}' to recreate the issue.", 2)}
EOE
        end

        results[:stdout].strip.lines.each do |line|
          parts = line.split(' ')

          unless info[:name]
            info[:name], info[:version], info[:release], info[:arch] = parts
          end

          info[:packages] << parts.first
        end

      else
        raise "Error: unable to read '#{rpm_source}'"
      end

      info[:full_version] = "#{info[:version]}-#{info[:release]}"

      return info
    end

    def self.indent(message, indent_length)
       message.split("\n").map {|line| ' '*indent_length + line }.join("\n")
    end

    # Loads metadata for a GPG key. The GPG key is to be used to sign RPMs. The
    # value of gpg_key should be the full path of the directory where the key
    # resides. If the metadata cannot be found, then the user will be prompted
    # for it.
    def self.load_key(gpg_key)
      keydir = gpg_key
      File.directory?(keydir) || fail("Error: Could not find '#{keydir}'")

      gpg_key = File.basename(gpg_key)

      if @@gpg_keys[gpg_key]
          return @@gpg_keys[gpg_key]
      end

      gpg_name = nil
      gpg_password = nil
      begin
        File.read("#{keydir}/gengpgkey").each_line do |ln|
          name_line = ln.split(/^\s*Name-Email:/)
          if name_line.length > 1
            gpg_name = name_line.last.strip
          end

          passwd_line = ln.split(/^\s*Passphrase:/)
          if passwd_line.length > 1
            gpg_password = passwd_line.last.strip
          end
        end
      rescue Errno::ENOENT
      end

      if gpg_name.nil?
        puts "Warning: Could not find valid e-mail address for use with GPG."
        puts "Please enter e-mail address to use:"
        gpg_name = $stdin.gets.strip
      end

      if gpg_password.nil?
        if File.exist?(%(#{keydir}/password))
          gpg_password = File.read(%(#{keydir}/password)).chomp
        end

        if gpg_password.nil?
          puts "Warning: Could not find a password in '#{keydir}/password'!"
          puts "Please enter your GPG key password:"
          system 'stty -echo'
          gpg_password = $stdin.gets.strip
          system 'stty echo'
        end
      end

      gpg_key_size = nil
      gpg_key_id = nil
      %x(gpg --homedir=#{keydir} --list-keys #{gpg_name} 2>&1).each_line do |line|
        head,data = line.split(/\s+/)
        if head == 'pub'
          gpg_key_size,gpg_key_id = data.split('/')
          break
        end
      end

      if !gpg_key_size || !gpg_key_id
        fail("Error getting GPG Key metadata")
      end

      @@gpg_keys[gpg_key] = {
        :dir => keydir,
        :name => gpg_name,
        :key_id => gpg_key_id,
        :key_size => gpg_key_size,
        :password => gpg_password
      }
    end

    # Signs the given RPM with the given gpg_key (see Simp::RPM.load_key for
    # details on the value of this parameter).
    def self.signrpm(rpm, gpg_key)
      gpgkey = load_key(gpg_key)

      gpg_sig = nil
      %x(rpm -Kv #{rpm}).each_line do |line|
        if line =~ /key\sID\s(.*):/
          gpg_sig = $1.strip
        end
      end

      unless gpg_sig == gpgkey[:key_id]
        signcommand = "rpm " +
            "--define '%_signature gpg' " +
            "--define '%__gpg %{_bindir}/gpg' " +
            "--define '%_gpg_name #{gpgkey[:name]}' " +
            "--define '%_gpg_path #{gpgkey[:dir]}' " +
            "--resign #{rpm}"
        begin
          PTY.spawn(signcommand) do |read, write, pid|
            begin
              while !read.eof? do
                read.expect(/pass\s?phrase:.*/) do |text|
                  write.puts(gpgkey[:password])
                  write.flush
                end
              end
            rescue Errno::EIO
              # This ALWAYS happens in Ruby 1.8.
            end
            Process.wait(pid)
          end

          raise "Failure running #{signcommand}" unless $?.success?
        rescue Exception => e
          puts "Error occured while attempting to sign #{rpm}, skipping."
          puts e
        end
      end
    end
  end
end
