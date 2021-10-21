require 'find'
require 'parallel'
require 'simp/rpm'
require 'simp/command_utils'

module Simp; end

# Class to sign RPMs.  Uses 'gpg' and 'rpm' executables.
class Simp::RpmSigner
  require 'expect'
  require 'pty'

  extend Simp::CommandUtils

  @@gpg_keys = Hash.new

  # Kill the GPG agent operating with the specified key dir, if
  # rpm version 4.13.0 or later.
  #
  # Beginning with version 4.13.0, rpm stands up a gpg-agent when
  # a signing operation is requested.
  def self.kill_gpg_agent(gpg_keydir)
    return if Gem::Version.new(Simp::RPM.version) < Gem::Version.new('4.13.0')

    %x(gpg-agent --homedir #{gpg_keydir} -q >& /dev/null)
    if $? && ($?.exitstatus == 0)
      # gpg-agent is running for specified keydir, so query it for its pid
      output = %x{echo 'GETINFO pid' | gpg-connect-agent --homedir=#{gpg_keydir}}
      if $? && ($?.exitstatus == 0)
        pid = output.lines.first[1..-1].strip.to_i
        begin
          Process.kill(0, pid)
          Process.kill(15, pid)
        rescue Errno::ESRCH
          # No longer running, so nothing to do!
        end
      end
    end
  end

  # Loads metadata for a GPG key found in gpg_keydir.
  #
  # The GPG key is to be used to sign RPMs. If the required metadata cannot be
  # retrieved from files found in the gpg_keydir, the user will be prompted
  # for it.
  #
  # @param gpg_keydir The full path of the directory where the key resides
  # @param verbose    Whether to log debug information.
  #
  # @raise If the 'gpg' executable cannot be found, the GPG key directory
  #   does not exist or GPG key metadata cannot be determined via 'gpg'
  #
  def self.load_key(gpg_keydir, verbose = false)
    which('gpg') || raise("ERROR: Cannot sign RPMs without 'gpg'")
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
    cmd = "gpg --with-colons --homedir=#{gpg_keydir} --list-keys '<#{gpg_name}>' 2>&1"
    puts "Executing: #{cmd}" if verbose
    %x(#{cmd}).each_line do |line|
      # See https://github.com/CSNW/gnupg/blob/master/doc/DETAILS
      # Index  Content
      #   0    record type
      #   2    key length
      #   4    keyID
      fields = line.split(':')
      if fields[0] && (fields[0] == 'pub')
        gpg_key_size = fields[2].to_i
        gpg_key_id = fields[4]
        break
      end
    end

    if !gpg_key_size || !gpg_key_id
      raise("Error getting GPG key ID or Key size metadata for #{gpg_name}")
    end

    @@gpg_keys[gpg_key] = {
      :dir      => gpg_keydir,
      :name     => gpg_name,
      :key_id   => gpg_key_id,
      :key_size => gpg_key_size,
      :password => gpg_password
    }
  end

  # Signs the given RPM with the GPG key found in gpg_keydir
  #
  # @param rpm          Fully qualified path to an RPM to be signed.
  # @param gpg_keydir   The full path of the directory where the key resides.
  # @param options      Options Hash
  #
  # @options options :digest_algo      Digest algorithm to use in RPM
  #                                    signing operation; defaults to 'sha256'
  # @options options :timeout_seconds  Timeout in seconds for an individual
  #                                    RPM signing operation; defaults to 60.
  # @options options :verbose          Whether to log debug information;
  #                                    defaults to false.
  #
  # @return Whether package signing operation succeeded
  # @raise RuntimeError if 'rpmsign' executable cannot be found, the 'gpg
  #   'executable cannot be found, the GPG key directory does not exist or
  #   the GPG key metadata cannot be determined via 'gpg'
  def self.sign_rpm(rpm, gpg_keydir, options={})
    # This may be a little confusing...Although we're using 'rpm --resign'
    # in lieu of 'rpmsign --addsign', they are equivalent and the presence
    # of 'rpmsign' is a legitimate check that the 'rpm --resign' capability
    # is available (i.e., rpm-sign package has been installed).
    which('rpmsign') || raise("ERROR: Cannot sign RPMs without 'rpmsign'.")

    digest_algo = options.key?(:digest_algo) ?  options[:digest_algo] : 'sha256'
    timeout_seconds = options.key?(:timeout_seconds) ?  options[:timeout_seconds] : 60
    verbose = options.key?(:verbose) ?  options[:verbose] : false

    gpgkey = load_key(gpg_keydir, verbose)

    gpg_sign_cmd_extra_args = nil
    if Gem::Version.new(Simp::RPM.version) >= Gem::Version.new('4.13.0')
      gpg_sign_cmd_extra_args = "--define '%_gpg_sign_cmd_extra_args --pinentry-mode loopback --verbose'"
    end

    signcommand = [
      'rpm',
      "--define '%_signature gpg'",
      "--define '%__gpg %{_bindir}/gpg'",
      "--define '%_gpg_name #{gpgkey[:name]}'",
      "--define '%_gpg_path #{gpgkey[:dir]}'",
      "--define '%_gpg_digest_algo #{digest_algo}'",
      gpg_sign_cmd_extra_args,
      "--resign #{rpm}"
    ].compact.join(' ')

    success = false
    begin
      if verbose
        puts "Signing #{rpm} with #{gpgkey[:name]} from #{gpgkey[:dir]}:\n  #{signcommand}"
      end

      require 'timeout'
      # With rpm-sign-4.14.2-11.el8_0 (EL 8.0), if rpm cannot start the
      # gpg-agent daemon, it will just hang. We need to be able to detect
      # the problem and report the failure.
      Timeout::timeout(timeout_seconds) do

        status = nil
        PTY.spawn(signcommand) do |read, write, pid|
          begin
            while !read.eof? do
              # rpm version >= 4.13.0 will stand up a gpg-agent and so the
              # prompt for the passphrase will only actually happen if this is
              # the first RPM to be signed with the key after the gpg-agent is
              # started and the key's passphrase has not been cleared from the
              # agent's cache.
              read.expect(/(pass\s?phrase:|verwrite).*/) do |text|
                if text.last.include?('verwrite')
                  write.puts('y')
                else
                  write.puts(gpgkey[:password])
                end

                write.flush
              end
            end
          rescue Errno::EIO
            # Will get here once input is no longer needed, which can be
            # immediately, if a gpg-agent is already running and the
            # passphrase for the key is loaded in its cache.
          end

          Process.wait(pid)
          status = $?
        end

        if status && !status.success?
          raise "Failure running <#{signcommand}>"
        end
      end

      puts "Successfully signed #{rpm}" if verbose
      success = true

    rescue Timeout::Error
      $stderr.puts "Failed to sign #{rpm} in #{timeout_seconds} seconds."
    rescue Exception => e
      $stderr.puts "Error occurred while attempting to sign #{rpm}:"
      $stderr.puts e
    end

    success
  end

  # Signs any RPMs found within the entire rpm_dir directory tree with
  # the GPG key found in gpg_keydir
  #
  # @param rpm_dir    A directory or directory glob pattern specifying 1 or
  #                   more directories containing RPM files to sign.
  # @param gpg_keydir The full path of the directory where the key resides
  # @param options    Options Hash
  #
  # @options options :digest_algo        Digest algorithm to use in RPM
  #                                      signing operation; defaults to
  #                                      'sha256'
  # @options options :force              Force RPMs that are already signed
  #                                      to be resigned; defaults to false.
  # @options options :max_concurrent     Maximum number of concurrent RPM
  #                                      signing operations; defaults to 1.
  # @options options :progress_bar_title Title for the progress bar logged to
  #                                      the console during the signing process;
  #                                      defaults to 'sign_rpms'.
  # @options options :timeout_seconds    Timeout in seconds for an individual
  #                                      RPM signing operation; defauls to 60.
  # @options options :verbose            Whether to log debug information;
  #                                      defaults to false.
  #
  # @return Hash of RPM signing results or nil if no RPMs found in rpm_dir
  #   * Each Hash key is the path to a RPM
  #   * Each Hash value is the status of the signing operation: :signed,
  #     :unsigned, :skipped_already_signed
  #
  # @raise RuntimeError if 'rpmsign' executable cannot be found, the 'gpg'
  #   executable cannot be found, the GPG key directory does not exist,
  #   the GPG key metadata cannot be determined via 'gpg' or any RPM signing
  #   operation failed
  #
  def self.sign_rpms(rpm_dir, gpg_keydir, options = {})
   opts = {
     :digest_algo        => 'sha256',
     :force              => false,
     :max_concurrent     => 1,
     :progress_bar_title => 'sign_rpms',
     :timeout_seconds    => 60,
     :verbose            => false
    }.merge(options)

    rpm_dirs = Dir.glob(rpm_dir)
    to_sign = []

    rpm_dirs.each do |rpm_dir|
      Find.find(rpm_dir) do |rpm|
        next unless File.readable?(rpm)
        to_sign << rpm if rpm =~ /\.rpm$/
      end
    end

    return nil if to_sign.empty?

    results = []
    begin
      results = Parallel.map(
        to_sign,
        :in_processes => 1,
        :progress => opts[:progress_bar_title]
      ) do |rpm|
        _result = nil

        begin
          if opts[:force] || !Simp::RPM.new(rpm).signature
            _result = [ rpm, sign_rpm(rpm, gpg_keydir, opts) ]
            _result[1] = _result[1] ? :signed : :unsigned
          else
            puts "Skipping signed package #{rpm}" if opts[:verbose]
            _result = [ rpm, :skipped_already_signed ]
          end
        rescue Exception => e
          # can get here if rpm is malformed and Simp::RPM.new fails
          $stderr.puts "Failed to sign #{rpm}:\n#{e.message}"
          _result = [ rpm, :unsigned ]
        end

        _result
      end
    ensure
      kill_gpg_agent(gpg_keydir)
    end

    results.to_h
  end

  def self.clear_gpg_keys_cache
    @@gpg_keys.clear
  end
end
