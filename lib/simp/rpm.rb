module Simp
  # Simp::RPM represents a single package that is built and packaged by the Simp team.
  class Simp::RPM
    require 'expect'
    require 'pty'

    @@gpg_keys = Hash.new
    attr_accessor :basename, :version, :release, :full_version, :name, :sources, :verbose

    if Gem.loaded_specs['rake'].version >= Gem::Version.new('0.9')
      def self.sh(args)
        system args
      end
    end

    # Constructs a new Simp::RPM object. Requires the path to the spec file
    # from which information will be gathered.
    #
    # The following information will be retreived:
    # [basename] The name of the package (as it would be queried in yum)
    # [version] The version of the package
    # [release] The release version of the package
    #   * NOTE: If this is a 'spec' file, it will stop on the first '%'
    #           encountered!
    # [full_version] The full version of the package: [version]-[release]
    # [name] The full name of the package: [basename]-[full_version]
    def initialize(rpm_source)
      info = Simp::RPM.get_info(rpm_source)
      @basename = info[:name]
      @version = info[:version]
      @release = info[:release]
      @full_version = info[:full_version]
      @name = "#{@basename}-#{@full_version}"
      @sources = Array.new
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

    # Parses information, such as the version, from the given specfile or RPM
    # into a hash.
    def self.get_info(rpm_source)
      info = Hash.new
      if File.readable?(rpm_source)
        if rpm_source.split('.').last == 'rpm'
          rpm_info = %x(rpm -q --queryformat '%{NAME} %{VERSION} %{RELEASE}' -p #{rpm_source} 2>/dev/null)
          info[:name],info[:version],info[:release] = rpm_info.split(' ')
        else
          File.open(rpm_source).each do |line|
            if line =~ /^\s*Version:\s+(.*)\s*/
              info[:version] = $1
              next
            elsif line =~ /^\s*Release:\s+(.*)\s*/
              # We don't want anything after the first '%'
              info[:release] = $1.split('%').first
              next
            elsif line =~ /^\s*Name:\s+(.*)\s*/
              info[:name] = $1
              next
            end
          end
        end
      else
        raise "Error: unable to read '#{rpm_source}'"
      end

      info[:full_version] = "#{info[:version]}-#{info[:release]}"

      return info
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

      @@gpg_keys[gpg_key] = { :dir => keydir, :name => gpg_name, :password => gpg_password }
    end

    # Signs the given RPM with the given gpg_key (see Simp::RPM.load_key for
    # details on the value of this parameter).
    def self.signrpm(rpm, gpg_key)
      gpgkey = load_key(gpg_key)
      signcommand = "rpm " +
          "--define '%_signature gpg' " +
          "--define '%__gpg %{_bindir}/gpg' " +
          "--define '%_gpg_name #{gpgkey[:name]}' " +
          "--define '%_gpg_path #{gpgkey[:dir]}' " +
          "--resign #{rpm}"
      begin
        PTY.spawn(signcommand) do |read, write, pid|
          begin
            read.expect(/Enter pass phrase: /) do |text|
              write.print("#{gpgkey[:password]}\n")
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
