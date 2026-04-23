# frozen_string_literal: true

require 'English'
# Various utilities for dealing with YUM repos
class Simp::Simp::YUM
  class Error < StandardError
  end

  require 'tmpdir'
  require 'facter'
  require 'simp/rpm'

  attr_reader :yum_conf

  def initialize(yum_conf, initialize_cache = false)
    raise(Error, "Could not find yum configuration at '#{yum_conf}'") unless File.exist?(yum_conf)

    @yum_conf = File.absolute_path(yum_conf)

    # Only need to look these up once!
    @@yum_cmd ||= `which yum`.strip
    raise(Error, "Error: Could not find 'yum'. Please install and try again.") if @@yum_cmd.empty?

    tmp_dir = ENV['TMPDIR'] || '/tmp'

    # Ensure that yumdownloader uses a fresh cache directory for each run of a given platform
    @@yum_cache ||= File.join(tmp_dir, "yum_cache-#{Facter.fact('operatingsystem').value}-#{Facter.fact('operatingsystemmajrelease').value}-#{Facter.fact('architecture').value}")

    FileUtils.mkdir_p(@@yum_cache)

    @@yum ||= "TMPDIR=#{@@yum_cache} #{@@yum_cmd} -c #{@yum_conf}"

    @@yumdownloader_cmd ||= `which yumdownloader`.strip
    raise(Error, "Error: Could not find 'yumdownloader'. Please install and try again.") if @@yumdownloader_cmd.empty?

    @@yumdownloader ||= "TMPDIR=#{@@yum_cache} #{@@yumdownloader_cmd} -c #{@yum_conf}"

    @@curl ||= `which curl`.strip
    raise(Error, "Error: Could not find 'curl'. Please install and try again.") if @@curl.empty?

    @@file ||= `which file`.strip
    raise(Error, "Error: Could not find 'file'. Please install and try again.") if @@file.empty?

    generate_cache if initialize_cache
  end

  def clean_yum_cache_dir
    # Make this as safe as we can
    return unless @@yum_cache.include?('yum_cache')

    FileUtils.remove_entry(@@yum_cache)
  end

  def generate_cache
    puts "Attempting to generate build-specific YUM cache from\n  #{@yum_conf}"

    `#{@@yum} clean all 2>/dev/null`
    `#{@@yum} makecache 2>/dev/null`

    return if $CHILD_STATUS.success?

    puts "WARNING: Unable to generate build-specific YUM cache from #{@yum_conf}"
  end

  # Create a reasonable YUM config file
  # * yum_tmp => The directory in which to store the YUM DB and any other temporary files
  #
  # Returns the location of the YUM configuration
  def self.generate_yum_conf(yum_dir = nil)
    yum_dir ||= Dir.pwd

    raise(Error, "Could not find YUM data dir at '#{yum_dir}'") unless File.directory?(yum_dir)

    yum_conf = nil
    Dir.chdir(yum_dir) do
      # Create the target directory
      yum_tmp = File.join('packages', 'yum_tmp')

      FileUtils.mkdir_p(yum_tmp) unless File.directory?(yum_tmp)

      yum_cache = File.expand_path('yum_cache', yum_tmp)
      FileUtils.mkdir_p(yum_cache) unless File.directory?(yum_cache)

      yum_logfile = File.expand_path('yum.log', yum_tmp)

      repo_dirs = []

      # Add the global directory
      repo_dirs << File.expand_path('../my_repos')

      repo_dirs << if File.directory?('my_repos')
                     # Add the local user repos if they exist
                     File.expand_path('my_repos')
                   else
                     # Add the default Internet repos otherwise
                     File.expand_path('repos')
                   end

      # Create our YUM config file
      yum_conf = File.expand_path('yum.conf', yum_tmp)

      File.open(yum_conf, 'w') do |fh|
        fh.puts <<-EOM.gsub(%r{^\s+}, '')
          [main]
          keepcache = 0
          persistdir = #{yum_cache}
          logfile = #{yum_logfile}
          exactarch = 1
          obsoletes = 0
          gpgcheck = 0
          plugins = 1
          reposdir = #{repo_dirs.join(' ')}
          assumeyes = 1
        EOM
      end
    end

    yum_conf
  end

  # Returns the full name of the latest package of the given name
  #
  # Returns nil if nothing found
  def available_package(rpm)
    yum_output = `#{@@yum} list #{rpm} 2>/dev/null`

    found_rpm = nil
    if $CHILD_STATUS.success?
      pkg_name, pkg_version = yum_output.lines.last.strip.split(%r{\s+})
      pkg_name, pkg_arch = pkg_name.split('.')

      found_rpm = %(#{pkg_name}-#{pkg_version}.#{pkg_arch}.rpm)
    end

    found_rpm
  end

  def get_sources(rpm)
    Dir.mktmpdir do |_dir|
      output = `#{@@yumdownloader} --urls #{File.basename(rpm, '.rpm')} 2>/dev/null`.lines
      sources = output.grep(%r{\.rpm$})

      unless output.grep(%r{Error}).empty? || sources.empty?
        err_msg = "\n-- YUMDOWNLOADER ERROR --\n#{output.join("\n")}"
        raise(Error, "No sources found for '#{rpm}'" + err_msg)
      end

      return sources
    end
  end

  def get_source(rpm, arch = nil)
    sources = get_sources(rpm)

    if arch
      native_sources = sources.grep(%r{(#{arch}|noarch)\.rpm$})

      if native_sources.size > 1
        # We can't have more than one native source
        raise(Error, "More than one native source found for #{rpm}:\n  * #{native_sources.join("\n  *")}")
      end
    end

    sources.first
  end

  def download(rpm, opts = { :target_dir => nil })
    rpm.strip!

    downloaded_rpm_name = nil

    target_dir = Dir.pwd

    if opts[:target_dir]
      target_dir = File.absolute_path(opts[:target_dir])
    end

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        # If just passed an RPM name, use yumdownloader
        if rpm.include?('://')
          # If passed a URL, curl it and fall back to yumdownloader
          rpm_name = rpm.split('/').last

          `#{@@curl} -L --max-redirs 10 -s -o #{rpm_name} -k #{rpm}`

          # Check what we've just downloaded
          unless File.exist?(rpm_name) && `#{@@file} #{rpm_name}`.include?('RPM')
            # Fall back on yumdownloader
            FileUtils.rm_f(rpm_name)

            `#{@@yumdownloader} #{File.basename(rpm_name, '.rpm')} 2>/dev/null`
          end

          # We might get a filename that doesn't make sense so we need to
          # move the file appropriately
          rpm_info = Simp::RPM.new(rpm_name)

          unless File.exist?(rpm_info.rpm_name)
            FileUtils.mv(rpm_name, rpm_info.rpm_name)
          end

          downloaded_rpm_name = rpm_info.rpm_name
        else
          # In case someone passed a path
          rpm_name = rpm.split(File::SEPARATOR).last

          `#{@@yumdownloader} #{File.basename(rpm_name, '.rpm')} 2>/dev/null`

          downloaded_rpm_name = rpm_name
        end

        rpms = Dir.glob('*.rpm')

        err_msg = ''
        err_msg = "\n-- ERROR MESSAGE --\n#{err_msg}" if err_msg
        raise(Error, "Could not find any remote RPMs for #{rpm}" + err_msg) if rpms.empty?

        # Copy over all of the RPMs
        rpms.each do |new_rpm|
          FileUtils.mkdir_p(target_dir)
          FileUtils.mv(new_rpm, target_dir)
        end
      end
    end

    downloaded_rpm_name
  end
end
