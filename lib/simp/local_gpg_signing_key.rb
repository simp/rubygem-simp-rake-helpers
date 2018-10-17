require 'securerandom'
require 'rake'

module Simp
  #  Ensure that a valid GPG signing key exists in a local directory
  #
  #    This is typically used to sign packages during development:
  #
  #    * The signing key will be generated if it is missing or expired.
  #    * Generated keys are short-lived (default: 14 days).
  #    * The signing key and its related assets are completely isolated from
  #      the user's own GPG keys, keyrings, and agent.
  #      - All files are kept under a local directory tree.
  #      - New keys are generated using a temporay GPG agent with its own
  #        settings and socket.
  #
  #    The local signing key's directory is structured like this:
  #
  #    ```
  #    #{key_name}/                        # key directory
  #      +-- RPM-GPG-KEY-SIMP-#{key_name}  # key file
  #      +-- gengpgkey                     # --gen-key params file **
  #      +-- pubring.gpg
  #      +-- secring.gpg
  #      +-- trustring.gpg
  #    ```
  #
  #    `**` = `SIMP::RPM.sign_keys` will look in the `gengpgkey` file for the
  #       signing key's email and passphrase
  #
  # Manage a development GPG key + GPG agent
  #
  #  A typical env-file looks like:
  #
  #  ```sh
  #  GPG_AGENT_INFO=/tmp/gpg-4yhfOB/S.gpg-agent:15495:1
  #  ```
  #
  #  The output of a brand-new gpg-agent daemon looks like:
  #
  #  ```sh
  #  GPG_AGENT_INFO=/tmp/gpg-4yhfOB/S.gpg-agent:15495:1; export GPG_AGENT_INFO;\n"
  #  ```
  #
  # @see SIMP::RPM.sign_keys

  class LocalGpgSigningKey
    include FileUtils

    # `SIMP::RPM.sign_keys` will look for a 'gengpgkey' file to
    #   non-interactively sign packages.
    #
    #   @see SIMP::RPM.sign_keys
    GPG_GENKEY_PARAMS_FILENAME = 'gengpgkey'.freeze

    # @param dir  [String] path to gpg-agent / key directory
    # @param opts [Hash] optional configurations
    #
    # @option opts [String]  :label         Defaults to the basename of `dir` (dev)
    # @option opts [String]  :email         (gatekeeper@simp.development.key)
    # @option opts [String]  :file          Default based on label (RPM-GPG-KEY-SIMP-Dev)
    # @option opts [Boolean] :verbose       (false)
    #
    def initialize(dir = 'dev', opts = {})
      @dir       = File.expand_path(dir)
      @label     = opts[:label]   || File.basename(dir.downcase)
      @key_email = opts[:email]   || 'gatekeeper@simp.development.key'
      @key_file  = opts[:file]    || "RPM-GPG-KEY-SIMP-#{@label.capitalize}"
      @verbose   = opts[:verbose] || false

      @gpg_agent_env_file = 'gpg-agent-info.env'
      @gpg_agent_script   = 'run_gpg_agent'
    end

    # Returns a gpg-agent's env string, if it can be detected
    #
    #   Places searched:
    #     - The @gpg_agent_env_file
    #     - ENV['GPG_AGENT_INFO']
    #
    #   @return [String] if the env string was detected
    #   @return [nil]    if the env string was not detected
    #
    def gpg_agent_info
      if File.exist?(@gpg_agent_env_file)
        puts "Reading gpg_agent_info from `#{@gpg_agent_env_file}`..." if @verbose
        info = parse_gpg_agent_info_env(File.read(@gpg_agent_env_file))
###      elsif File.exist?((ENV['GPG_AGENT_INFO']).to_s.split(':').first || '')
###        puts "Reading gpg_agent_info from `ENV['GPG_AGENT_INFO']`..." if @verbose
###        info = parse_gpg_agent_info_env('GPG_AGENT_INFO=' + ENV['GPG_AGENT_INFO'])
      else
        puts "Couldn't find a valid source to read gpg_agent_info..." if @verbose
        info = nil
      end
      info
    end

    # Return the number of days left before the GPG signing key expires
    #
    #   @note This doesn't require a gpg-agent or socket to function
    def dev_key_days_left
      ensure_gpg_directory
      days_left   = 0
      current_key = %x(GPG_AGENT_INFO='' gpg --homedir=#{@dir} --list-keys #{@key_email} 2>/dev/null)
      unless current_key.empty?
        lasts_until = current_key.lines.first.strip.split("\s").last.delete(']')
        days_left = (Date.parse(lasts_until) - Date.today).to_i
      end
      days_left
    end

    # Remove all files under the key directory
    def clean_gpg_agent_directory
      puts "  Removing all files under '#{@dir}'" if @verbose
      Dir.glob(File.join(@dir, '*')).each do |todel|
        rm_rf(todel, :verbose => @verbose)
      end
    end

    # Make sure the local key's directory exists and has correct permissions
    def ensure_gpg_directory
      mkdir_p(@dir, :verbose => @verbose)
      chmod(0o700, @dir, :verbose => @verbose)
    end

    # Ensure that the gpg-agent is running with a a dev key
    def ensure_key
      ensure_gpg_directory

      if (days_left = dev_key_days_left) > 0
        puts "GPG key (#{@key_email}) will expire in #{days_left} days."
        return
      end

      Dir.chdir @dir do |_dir|
        puts 'Creating a new dev GPG agent...'

        clean_gpg_agent_directory
        write_genkey_parameter_file
        write_gpg_agent_startup_script

        begin
          # Start the GPG agent.
          gpg_agent_output = %x(./#{@gpg_agent_script}).strip

          # The local socket
          local_socket     = File.join(Dir.pwd, 'S.gpg-agent')

          # This condition was handled differently in previous logic, but:
          #
          #   a.) As the surrounding logic works now, it will _always_ be a new
          #       agent by this point because the directory is cleaned out
          #   b.) The `gpg-agent --homedir=#{Dir.pwd} /get serverpid`
          #
          if gpg_agent_output.empty?

          end

          agent_info = gpg_agent_info

          # get back info on the command line.
          unless File.exist?(File.join(Dir.pwd, File.basename(agent_info[:socket])))
            ln_s(agent_info[:socket], local_socket, :verbose => @verbose)
          end
          generate_key(agent_info[:info])
        ensure
          kill_agent(agent_info[:pid])
        end
        agent_info
      end
    end

    def kill_agent(pid)
      rm('S.gpg-agent') if File.symlink?('S.gpg-agent')
      if pid
        Process.kill(0, pid)
        Process.kill(15, pid)
      end
    rescue Errno::ESRCH
      # Not Running, Nothing to do!
    end

    # Generate a RPM GPG signing key for local development
    def generate_key(gpg_agent_info_str)
      puts "Generating new GPG key#{@verbose ? " under '#{@dir}'" : ''}..."
      gpg_cmd = %(GPG_AGENT_INFO=#{gpg_agent_info_str} gpg --homedir="#{@dir}")
      pipe    = @verbose ? '| tee' : '>'
      sh %(#{gpg_cmd} --batch --gen-key #{GPG_GENKEY_PARAMS_FILENAME})
      sh %(#{gpg_cmd} --armor --export #{@key_email} #{pipe} "#{@key_file}")
    end

    # Return a data structure from a gpg-agent env-file formatted string.
    #
    # @param `str`  [String] path to gpg-agent / key directory
    def parse_gpg_agent_info_env(str)
      info    = %r{^(GPG_AGENT_INFO=)?(?<info>[^;]+)}.match(str)[:info]
      matches = %r{^(?<socket>[^:]+):(?<pid>[^:]+)}.match(info)
      { info: info.strip, socket: matches[:socket], pid: matches[:pid].to_i }
    end

    # Write the `gpg --genkey --batch` control parameters file
    #
    # @see "Unattended key generation" in /usr/share/doc/gnupg2-*/DETAILS for
    #   documentation on the command parameters format
    def write_genkey_parameter_file
      now               = Time.now.to_i.to_s
      expire_date       = Date.today + 14
      passphrase        = SecureRandom.base64(500)
      genkey_parameters = <<-GENKEY_PARAMETERS.gsub(%r{^ {8}}, '')
        %echo Generating Development GPG Key
        %echo
        %echo This key will expire on #{expire_date}
        %echo
        Key-Type: RSA
        Key-Length: 4096
        Key-Usage: sign
        Name-Real: SIMP Development
        Name-Comment: Development key #{now}
        Name-Email: #{@key_email}
        Expire-Date: 2w
        Passphrase: #{passphrase}
        %pubring pubring.gpg
        %secring secring.gpg
        # The following creates the key, so we can print "Done!" afterwards
        %commit
        %echo New GPG Development Key Created
      GENKEY_PARAMETERS
      File.open(GPG_GENKEY_PARAMS_FILENAME, 'w') { |fh| fh.puts(genkey_parameters) }
    end

    # Write a local gpg-agent daemon script file
    def write_gpg_agent_startup_script
      gpg_agent_script = <<-AGENT_SCRIPT.gsub(%r{^ {20}}, '')
        #!/bin/sh

        gpg-agent --homedir=#{Dir.pwd} --daemon \
          --no-use-standard-socket --sh --batch \
          --write-env-file "#{@gpg_agent_env_file}" \
          --pinentry-program /usr/bin/pinentry-curses < /dev/null &
      AGENT_SCRIPT

      File.open(@gpg_agent_script, 'w') { |fh| fh.puts(gpg_agent_script) }
      chmod(0o755, @gpg_agent_script)
    end
  end
end
