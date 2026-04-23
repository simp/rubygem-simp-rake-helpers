# frozen_string_literal: true

require 'securerandom'

module Simp
  # An Simp::RPM instance represents RPM metadata extracted from an
  # RPM or an RPM spec file.
  #
  # Simp::RPM also contains class methods that are useful for
  # processing RPMs in the SIMP build process.
  #
  # @note Set the environment variable `SIMP_RPM_dist` to ensure all
  #       packages use a particular dist.
  class Simp::RPM
    require 'expect'
    require 'pty'
    require 'rake'

    attr_reader :verbose, :lua_debug, :packages

    if Gem.loaded_specs['rake'].version >= Gem::Version.new('0.9')
      def self.sh(args)
        system args
      end
    end

    def self.rpm_cmd
      @rpm_cmd ||= (ENV.fetch('SIMP_RPM_LUA_debug', 'no') == 'yes') ? "rpm -D 'lua_debug 1'" : 'rpm'
    end

    # Constructs a new Simp::RPM object. Requires the path to the spec file, or
    # RPM, from which information will be gathered.
    #
    # When the information is from a spec file, multiple
    # packages may exist.
    #
    # The following information will be retrieved per package:
    #
    # [basename] The name of the package (as it would be queried in yum)
    # [version] The version of the package
    # [release] The release version of the package
    # [full_version] The full version of the package: [version]-[release]
    # [name] The full name of the package: [basename]-[full_version]
    # [arch] The machine architecture of the package
    # [signature] The signature key of the package, if it exists. Will not
    #   apply when +rpm_source+ is an RPM spec file.
    # [rpm_name] The full name of the rpm
    def initialize(rpm_source)
      @verbose = ENV.fetch('SIMP_RPM_verbose', 'no') == 'yes'

      update_rpmmacros

      # Simp::RPM.get_info returns a Hash or an Array of Hashes.
      # Steps below prevent single Hash from implicitly being converted
      # to Array using Hash.to_a.
      info_array = []
      info_array << Simp::RPM.get_info(rpm_source)
      info_array.flatten!

      @info = {}
      info_array.each do |package_info|
        @info[package_info[:basename]] = package_info
      end

      @packages = @info.keys

      return unless @verbose

      require 'pp'
      puts '== Simp::RPM @packages'
      puts @packages.pretty_inspect
    end

    # @returns The RPM '.dist' of the system. 'nil' will be will be
    #          returned if the dist is not found.
    # @note This causes problems for ISO builds that target a particular
    #       OS if it doesn't match the host.  Set the environment variable
    #       `SIMP_RPM_dist` to ensure all packages use a particular dist.
    def self.system_dist
      # We can only have one of these
      unless defined?(@@system_dist)
        cmd  = %(#{rpm_cmd} -E '%{dist}' 2> /dev/null)
        if @verbose
          puts '== Simp::RPM.system_dist'
          puts "   #{cmd} "
        end
        dist = `#{cmd}`.strip.split('.')
        puts "  result = '#{dist}'" if @verbose

        @@system_dist = if dist.size > 1
                          (dist[1] =~ %r{^\.}) ? dist[1] : ('.' + dist[1])
                        else
                          nil
                        end
        puts "  @@system_dist = #{@@system_dist || 'nil'}" if @verbose
      end

      @@system_dist
    end

    def system_dist
      Simp::RPM.system_dist
    end

    # Work around the silliness with 'centos' being tacked onto things via the
    # 'dist' flag
    def update_rpmmacros
      return if defined?(@@macros_updated)

      # Workaround for CentOS system builds
      dist           = ENV['SIMP_RPM_dist'] || system_dist
      dist_macro     = %(%dist #{dist})
      rpmmacros      = [dist_macro]
      rpmmacros_file = File.join(Dir.home, '.rpmmacros')

      if File.exist?(rpmmacros_file)
        rpmmacros = File.read(rpmmacros_file).split("\n")

        dist_index = rpmmacros.each_index.find { |i| rpmmacros[i] =~ %r{^%dist\s+} }

        if dist_index
          rpmmacros[dist_index] = dist_macro
        else
          rpmmacros << dist_macro
        end
      end

      File.open(rpmmacros_file, 'w') do |fh|
        fh.puts rpmmacros.join("\n")
        fh.flush
      end

      if @verbose
        puts '== SIMP::RPM#update_rpmmacros:'
        puts "   wrote to '#{rpmmacros_file}': "
        puts "   #{'-' * 20}"
        puts rpmmacros.map { |x| "   #{x}\n" }.join
        puts
      end
      @@macros_updated = true
    end

    # @returns The name of the package (as it would be queried in yum)
    #
    # @fails if package is invalid
    def basename(package = @packages.first)
      valid_package?(package)
      @info[package][:basename]
    end

    # @returns The version of the package
    #
    # @fails if package is invalid
    def version(package = @packages.first)
      valid_package?(package)
      @info[package][:version]
    end

    # @returns The release version of the package
    #
    # @fails if package is invalid
    def release(package = @packages.first)
      valid_package?(package)
      @info[package][:release]
    end

    # @returns The full version of the package: [version]-[release]
    #
    # @fails if package is invalid
    def full_version(package = @packages.first)
      valid_package?(package)
      @info[package][:full_version]
    end

    # @returns The full name of the package: [basename]-[full_version]
    # @fails if package is invalid
    def name(package = @packages.first)
      valid_package?(package)
      @info[package][:name]
    end

    # @returns The machine architecture of the package
    #
    # @fails if package is invalid
    def arch(package = @packages.first)
      valid_package?(package)
      @info[package][:arch]
    end

    # @returns The signature key of the package, if it exists or nil
    #   otherwise. Will always be nil when the information for this
    #   object was derived from an RPM spec file.
    #
    # @fails if package is invalid
    def signature(package = @packages.first)
      valid_package?(package)
      @info[package][:signature]
    end

    # @returns The full name of the RPM
    #
    # @fails if package is invalid
    def rpm_name(package = @packages.first)
      valid_package?(package)
      @info[package][:rpm_name]
    end

    # @returns Whether or not the package has a `dist` tag
    #
    # @fails if package is invalid
    def has_dist_tag?(package = @packages.first)
      valid_package?(package)
      @info[package][:has_dist_tag]
    end

    # @returns The `dist` of the package. If no `dist` is found, returns the
    # `dist` of the OS itself. Logic should check both `has_dist_tag?` and
    # `dist`
    #
    # @fails if package is invalid
    def dist(package = @packages.first)
      valid_package?(package)
      @info[package][:dist]
    end

    # Returns whether or not the current RPM package is
    # newer than the passed RPM.
    #
    # Uses the first package in the package list as the
    # current RPM package.
    def newer?(other_rpm)
      package_newer?(@packages.first, other_rpm)
    end

    # Returns whether or not the current RPM sub-package is
    # newer than the passed RPM.
    def package_newer?(package, other_rpm)
      valid_package?(package)
      return true if other_rpm.nil? || other_rpm.empty?

      unless %r{\.rpm$}.match?(other_rpm)
        raise ArgumentError, "You must pass valid RPM name! Got: '#{other_rpm}'"
      end

      if File.readable?(other_rpm)
        other_full_version = Simp::RPM.get_info(other_rpm)[:full_version]
      else
        # determine RPM info in a hacky way, ASSUMING, the other RPM has the
        # same basename and arch
        other_full_version = other_rpm.gsub(%r{#{package}-}, '').gsub(%r{.rpm$}, '')
        package_arch = arch(package)
        unless package_arch.nil? || package_arch.empty?
          other_full_version.gsub!(%r{.#{package_arch}}, '')
        end
      end

      begin
        Gem::Version.new(full_version(package)) > Gem::Version.new(other_full_version)
      rescue ArgumentError, NoMethodError
        raise("Could not compare RPMs '#{rpm_name(package)}' and '#{other_rpm}'")
      end
    end

    def valid_package?(package)
      return false if @packages.include?(package)

      raise ArgumentError, "'#{package}' is not a valid sub-package"
    end

    # Copies specific content from one directory to another.
    # start_dir:: the root directory where the original files are located within
    # src:: a pattern given to find(1) to match against the desired files to copy
    # dest:: the destination directory to receive the copies
    def self.copy_wo_vcs(start_dir, src, dest, dereference = true)
      dereference = if dereference.nil? || dereference
                      '--dereference'
                    else
                      ''
                    end

      Dir.chdir(start_dir) do
        sh %{find #{src} \\( -path "*/.svn" -a -type d -o -path "*/.git*" \\) -prune -o -print | cpio -u --warning none --quiet --make-directories #{dereference} -p "#{dest}" 2>&1 > /dev/null}
      end
    end

    # Executes a command and returns a hash with the exit status,
    # stdout output and stderr output.
    # cmd:: command to be executed
    def self.execute(cmd)
      if @verbose ||= ENV.fetch('SIMP_RPM_verbose', 'no') == 'yes'
        puts "== Simp::RPM.execute(#{cmd})"
        puts "  #{cmd}"
      end

      outfile = File.join('/tmp', "#{ENV.fetch('USER', nil)}_#{SecureRandom.hex}")
      errfile = File.join('/tmp', "#{ENV.fetch('USER', nil)}_#{SecureRandom.hex}")
      pid = spawn(cmd, :out => outfile, :err => errfile)

      begin
        _, status = Process.wait2(pid)
      rescue Errno::ECHILD
        # process exited before status could be determined
      end

      exit_status = status&.exitstatus
      stdout = File.read(outfile)
      stderr = File.read(errfile)

      { :exit_status => exit_status, :stdout => stdout, :stderr => stderr }
    ensure
      if @verbose
        puts "    -------- exit_status: #{exit_status}"
        puts '    -------- stdout ', ''
        puts File.readlines(outfile).map { |x| "    #{x}" }.join
        puts '', '    -------- stderr ', ''
        puts File.readlines(errfile).map { |x| "    #{x}" }.join
      end
      FileUtils.rm_f([outfile, errfile])
    end

    # Parses information, such as the version, from the given specfile
    # or RPM into a hash.
    #
    # If the information from only single RPM is extracted, returns a
    # single Hash with the following possible keys:
    #   :has_dist_tag = a boolean indicating whether the RPM release
    #                    has a distribution field; only evaluated when
    #                    rpm_source is a spec file, otherwise false
    #   :basename      = The name of the package (as it would be
    #                    queried in yum)
    #   :version       = The version of the package
    #   :release       = The release version of the package
    #   :arch          = The machine architecture of the package
    #   :full_version  = The full version of the package:
    #                      <version>-<release>
    #   :name          = The full name of the package:
    #                      <basename>-<full_version>
    #   :rpm_name      = The full name of the RPM:
    #                      <basename>-<full_version>.<arch>.rpm
    #   :signature     = RPM signature key id; only present if
    #                    rpm_source is an RPM and the RPM is signed
    #
    # If the information from more than one RPM is extracted, as is the case
    # when a spec file specifies sub-packages, returns an Array of Hashes.
    #
    def self.get_info(rpm_source)
      raise "Error: unable to read '#{rpm_source}'" unless File.readable?(rpm_source)

      target_dist = if ENV['SIMP_RPM_dist']
                      (ENV.fetch('SIMP_RPM_dist', nil) =~ %r{^\.}) ? ENV.fetch('SIMP_RPM_dist', nil) : ('.' + ENV.fetch('SIMP_RPM_dist', nil))
                    else
                      system_dist
                    end

      info_array = []
      common_info = {}

      rpm_version_query = %(#{rpm_cmd} -q --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\\n')

      rpm_signature_query = %(#{rpm_cmd} -q --queryformat '%|DSAHEADER?{%{DSAHEADER:pgpsig}}:{%|RSAHEADER?{%{RSAHEADER:pgpsig}}:{%|SIGGPG?{%{SIGGPG:pgpsig}}:{%|SIGPGP?{%{SIGPGP:pgpsig}}:{(none)}|}|}|}|\\n') # rubocop:disable Layout/LineLength

      source_is_rpm = rpm_source.split('.').last == 'rpm'
      if source_is_rpm
        dist_info = rpm_source.split('-').last.split('.')[1..-3]

        if dist_info.empty?
          common_info[:has_dist_tag] = false
          common_info[:dist] = target_dist
        else
          common_info[:has_dist_tag] = true
          common_info[:dist] = '.' + dist_info.first
        end
      elsif File.read(rpm_source).include?('%{?dist}')
        common_info[:dist] = target_dist
        common_info[:has_dist_tag] = true
      else
        common_info[:has_dist_tag] = false
        common_info[:dist] = target_dist
      end

      unless source_is_rpm
        macros = {
          'dist' => target_dist
        }
        macros.each do |k, v|
          rpm_version_query += %( -D '#{k} #{v}')
        end

      end

      if source_is_rpm
        query_source = "-p #{rpm_source}"
        version_results = execute("#{rpm_version_query} #{query_source}")
        signature_results = execute("#{rpm_signature_query} #{query_source}")
      else
        query_source = "--specfile #{rpm_source}"
        version_results = execute("#{rpm_version_query} #{query_source}")
        signature_results = nil
      end

      if version_results[:exit_status] != 0
        raise <<~EOE
          #{indent('Error getting RPM info for #{query_source}:', 2)}
          #{indent(version_results[:stderr].strip, 5)}
          #{indent("Run '#{rpm_version_query.gsub("\n", '\\n')} #{query_source}' to recreate the issue.", 2)}
        EOE
      end

      unless signature_results.nil?
        raise <<~EOE if signature_results[:exit_status] != 0
            #{indent('Error getting RPM signature for #{query_source}:', 2)}
            #{indent(signature_results[:stderr].strip, 5)}
            #{indent("Run '#{rpm_signature_query.gsub("\n", '\\n')} #{query_source}' to recreate the issue.", 2)}
        EOE

        signature = signature_results[:stdout].strip
      end

      version_results[:stdout].strip.lines.each do |line|
        info = common_info.dup
        parts = line.split

        info[:basename], info[:version], info[:release], info[:arch] = parts
        info[:signature]    = signature unless signature.nil? || signature.include?('none')
        info[:full_version] = "#{info[:version]}-#{info[:release]}"
        info[:name]         = "#{info[:basename]}-#{info[:full_version]}"
        info[:rpm_name]     = "#{info[:name]}.#{info[:arch]}.rpm"

        info_array << info
      end

      if @verbose
        puts '== SIMP::RPM.get_info'
        require 'pp'
        pp info_array
      end

      if info_array.size == 1
        info_array[0]
      else
        # will only happen when source is spec file and that spec file
        # specifies sub-packages
        info_array
      end
    end

    def self.indent(message, indent_length)
      message.split("\n").map { |line| (' ' * indent_length) + line }.join("\n")
    end

    def self.create_rpm_build_metadata(project_dir, srpms = nil, rpms = nil)
      require 'yaml'

      last_build = {
        'git_hash' => `git rev-list --max-count=1 HEAD`.chomp,
        'srpms' => {},
        'rpms' => {}
      }

      Dir.chdir(File.join(project_dir, 'dist')) do
        if srpms.nil? || rpms.nil?
          all_rpms = Dir.glob('*.rpm')
          srpms = Dir.glob('src.rpm')
          rpms = all_rpms - srpms
        end

        srpms.each do |srpm|
          file_stat = File.stat(srpm)

          last_build['srpms'][File.basename(srpm)] = {
            'metadata' => Simp::RPM.get_info(srpm),
            'size' => file_stat.size,
            'timestamp' => file_stat.ctime,
            'path' => File.absolute_path(srpm)
          }
        end

        rpms.each do |rpm|
          file_stat = File.stat(rpm)

          last_build['rpms'][File.basename(rpm)] = {
            'metadata' => Simp::RPM.get_info(rpm),
            'size' => file_stat.size,
            'timestamp' => file_stat.ctime,
            'path' => File.absolute_path(rpm)
          }
        end

        FileUtils.mkdir_p(File.join(project_dir, 'dist', 'logs'))
        File.open('logs/last_rpm_build_metadata.yaml', 'w') do |fh|
          fh.puts(last_build.to_yaml)
        end
      end
    end

    # Returns the version of RPM installed on the system
    def self.version
      `rpm --version`.strip.split.last
    end
  end
end
