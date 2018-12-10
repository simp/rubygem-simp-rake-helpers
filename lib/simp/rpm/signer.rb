require 'find'
require 'parallel'
require 'simp/rpm/packageinfo'
require 'simp/utils'

module Simp; end
module Simp::Rpm; end


# Class to sign RPMs.  Uses 'gpg' and 'rpmsign' executables.
class Simp::Rpm::Signer
  require 'expect'
  require 'pty'

  @@gpg_keys = Hash.new

  # Loads metadata for a GPG key found in gpg_keydir.
  #
  # The GPG key is to be used to sign RPMs. If the required metadata
  # cannot be found in gpg_keydir, then the user will be prompted for it.
  #
  #  +gpg_keydir+:: The full path of the directory where the key resides
  #
  # @raise If the 'gpg' executable cannot be found, the GPG key directory
  #   does not exist or the GPG key metadata cannot be determined via 'gpg'
  #
  def self.load_key(gpg_keydir)
    Simp::Utils::which('gpg') || raise("ERROR: Cannot sign RPMs without 'gpg'")
    File.directory?(gpg_keydir) || raise("ERROR: Could not find GPG keydir '#{gpg_keydir}'")

    gpg_key = File.basename(gpg_keydir)

    if @@gpg_keys[gpg_key]
      return @@gpg_keys[gpg_key]
    end

    gpg_name = nil
    gpg_password = nil
    begin
      File.read("#{gpg_keydir}/gengpgkey").each_line do |ln|
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
      if File.exist?(%(#{gpg_keydir}/password))
        gpg_password = File.read(%(#{gpg_keydir}/password)).chomp
      end

      if gpg_password.nil?
        puts "Warning: Could not find a password in '#{gpg_keydir}/password'!"
        puts "Please enter your GPG key password:"
        system 'stty -echo'
        gpg_password = $stdin.gets.strip
        system 'stty echo'
      end
    end

    gpg_key_size = nil
    gpg_key_id = nil
    %x(gpg --homedir=#{gpg_keydir} --list-keys #{gpg_name} 2>&1).each_line do |line|
      head,data = line.split(/\s+/)
      if head == 'pub'
        gpg_key_size,gpg_key_id = data.split('/')
        break
      end
    end

    if !gpg_key_size || !gpg_key_id
      raise('Error getting GPG Key metadata')
    end

    @@gpg_keys[gpg_key] = {
      :dir => gpg_keydir,
      :name => gpg_name,
      :key_id => gpg_key_id,
      :key_size => gpg_key_size,
      :password => gpg_password
    }
  end

  # Signs the given RPM with the GPG key found in gpg_keydir
  #
  # +rpm+::        Fully qualified path to an RPM to be signed.
  # +gpg_keydir+:: The full path of the directory where the key resides.
  # +verbose+::    Whether to log debug information.
  #
  # @raise RuntimeError if 'rpmsign' executable cannot be found, the 'gpg
  #   'executable cannot be found, the GPG key directory does not exist or
  #   the GPG key metadata cannot be determined via 'gpg'
  def self.sign_rpm(rpm, gpg_keydir, verbose = false)
    # This may be a little confusing...Although we're using 'rpm --resign'
    # in lieu of 'rpmsign --addsign', they are equivalent and the presence
    # of 'rpmsign' is a legitimate check that the 'rpm --resign' capability
    # is available (i.e., rpm-sign package has been installed).
    Simp::Utils::which('rpmsign') || raise("ERROR: Cannot sign RPMs without 'rpmsign'.")

    gpgkey = load_key(gpg_keydir)

    signcommand = "rpm " +
        "--define '%_signature gpg' " +
        "--define '%__gpg %{_bindir}/gpg' " +
        "--define '%_gpg_name #{gpgkey[:name]}' " +
        "--define '%_gpg_path #{gpgkey[:dir]}' " +
        "--resign #{rpm}"

    begin
      puts "Signing #{rpm} with #{gpgkey[:name]} from #{gpgkey[:dir]}" if verbose
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
      $stderr.puts "Error occurred while attempting to sign #{rpm}, skipping."
      $stderr.puts e
    end
  end

  # Signs any RPMs found within the entire rpm_dir directory tree with
  # the GPG key found in gpg_keydir
  #
  # +rpm_dir+::    A directory or directory glob pattern specifying 1 or more
  #                directories containing RPM files to sign.
  # +gpg_keydir+:: The full path of the directory where the key resides
  # +force+::      Force RPMs that are already signed to be resigned.
  # +progress_bar_title+:: Title for the progress bar logged to the
  #                console during the signing process.
  # +max_concurrent+:: Maximum number of concurrent RPM signing
  #                operations
  # +verbose+::    Whether to log debug information.
  #
  # @raise RuntimeError if 'rpmsign' executable cannot be found, the 'gpg'
  #   executable cannot be found, the GPG key directory does not exist or
  #   the GPG key metadata cannot be determined via 'gpg'
  #
  #   **All other RPM signing errors are logged and ignored.**
  #
  def self.sign_rpms(rpm_dir, gpgkey_dir, force=false,
      progress_bar_title = 'sign_rpms', max_concurrent = 1, verbose = false)

    rpm_dirs = Dir.glob(rpm_dir)
    to_sign = []

    rpm_dirs.each do |rpm_dir|
      Find.find(rpm_dir) do |rpm|
        next unless File.readable?(rpm)
        to_sign << rpm if rpm =~ /\.rpm$/
      end
    end

    Parallel.map(
      to_sign,
      :in_processes => max_concurrent,
      :progress => progress_bar_title
    ) do |rpm|

      if force || !Simp::Rpm::PackageInfo.new(rpm, verbose).signature
        sign_rpm(rpm, gpgkey_dir, verbose)
      else
        puts "Skipping signed package #{rpm}" if verbose
      end
    end
  end

end
