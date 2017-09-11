module Simp
  # Various utilities for dealing with YUM repos
  class Simp::YUM

    class Error < StandardError
    end

    require 'tmpdir'
    require 'facter'
    require 'simp/rpm'

    attr_reader :yum_conf

    def initialize(yum_conf)
      if File.exist?(yum_conf)
        @yum_conf = File.absolute_path(yum_conf)
      else
        raise(Error, "Could not find yum configuration at '#{yum_conf}'")
      end

      # Only need to look these up once!
      @@yumdownloader ||= %x(which yumdownloader).strip
      raise(Error, "Error: Could not find 'yumdownloader'. Please install and try again.") if @@yumdownloader.empty?

      tmp_dir = ENV['TMPDIR'] || '/tmp'

      # Ensure that yumdownloader uses a fresh cache directory for each run of a given platform
      @@yumdownloader_cache ||= File.join(tmp_dir, 'yumdownloader_cache-' +
        Facter.fact('operatingsystem').value + '-' +
        Facter.fact('operatingsystemmajrelease').value + '-' +
        Facter.fact('architecture').value)

      FileUtils.mkdir_p(@@yumdownloader_cache)

      @@yumdownloader = "TMPDIR=#{@@yumdownloader_cache} #{@@yumdownloader}"

      @@curl ||= %x(which curl).strip
      raise(Error, "Error: Could not find 'curl'. Please install and try again.") if @@curl.empty?

      @@file ||= %x(which file).strip
      raise(Error, "Error: Could not find 'file'. Please install and try again.") if @@file.empty?
    end

    def clean_yumdownloader_cache_dir
      # Make this as safe as we can
      if @@yumdownloader_cache =~ /yumdownloader_cache/
        FileUtils.remove_entry(@@yumdownloader_cache)
      end
    end

    # Create a reasonable YUM config file
    # * yum_tmp => The directory in which to store the YUM DB and any other temporary files
    #
    # Returns the location of the YUM configuration
    def self.generate_yum_conf(yum_dir=nil)
      yum_dir ||= Dir.pwd

      raise(Error, "Could not find YUM data dir at '#{yum_dir}'") unless File.directory?(yum_dir)

      yum_conf = nil
      Dir.chdir(yum_dir) do
        # Create the target directory
        yum_tmp = File.join('packages','yum_tmp')

        FileUtils.mkdir_p(yum_tmp) unless File.directory?(yum_tmp)

        yum_cache = File.expand_path('yum_cache', yum_tmp)
        FileUtils.mkdir_p(yum_cache) unless File.directory?(yum_cache)

        yum_logfile = File.expand_path('yum.log', yum_tmp)

        repo_dirs = []

        # Add the global directory
        repo_dirs << File.expand_path('../my_repos')

        if File.directory?('my_repos')
          # Add the local user repos if they exist
          repo_dirs << File.expand_path('my_repos')
        else
          # Add the default Internet repos otherwise
          repo_dirs << File.expand_path('repos')
        end

        # Create our YUM config file
        yum_conf = File.expand_path('yum.conf', yum_tmp)

        File.open(yum_conf, 'w') do |fh|
          fh.puts <<-EOM.gsub(/^\s+/,'')
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

      return yum_conf
    end

    def get_sources(rpm)

      if rpm =~ %r((/|\.rpm$))
        raise(Error, "get_sources can only accept short RPM names, got '#{rpm}'")
      end

      sources = %x(#{@@yumdownloader} -c #{@yum_conf} --urls #{File.basename(rpm,'.rpm')} 2>/dev/null).split("\n").grep(%r(\.rpm$))

      raise(Error, "No sources found for '#{rpm}'") if sources.empty?

      return sources
    end

    def get_source(rpm, arch=nil)
      sources = get_sources(rpm, arch)

      if arch
        native_sources = sources.grep(%r((#{arch}|noarch)\.rpm$))

        if native_sources.size > 1
          # We can't have more than one native source
          raise(Error, "More than one native source found for #{rpm}:\n  * #{native_sources.join("\n  *")}")
        end
      end

      return sources.first
    end

    def download(rpm, opts={:target_dir => nil})
      target_dir = Dir.pwd

      if opts[:target_dir]
        target_dir = File.absolute_path(opts[:target_dir])
      end

      Dir.mktmpdir do |dir|
        # If just passed an RPM name, use yumdownloader
        if rpm !~ %r(://)
          # In case someone passed a path
          rpm_name = rpm.split(File::SEPARATOR).last

          %x(#{@@yumdownloader} -c #{@yum_conf} #{File.basename(rpm_name, '.rpm')} 2> /dev/null)
        else
          # If passed a URL, curl it and fall back to yumdownloader
          rpm_name = rpm.split('/').last

          %x(#{@@curl} -L --max-redirs 10 -s -o #{rpm_name} -k #{rpm})

          # Check what we've just downloaded
          if !(File.exist?(rpm_name) || %x(#{@@file} #{rpm_name}).include('RPM'))
            # Fall back on yumdownloader
            FileUtils.rm_f(rpm_name)

            %x(#{@@yumdownloader} -c #{@yum_conf} #{File.basename(rpm_name, '.rpm')} 2> /dev/null)
          end
        end

        rpms = Dir.glob('*.rpm')
        raise(Error, "Could not find any remote RPMs for #{rpm}") if rpms.empty?

        # Copy over all of the RPMs
        rpms.each do |new_rpm|
          FileUtils.mkdir_p(target_dir)
          FileUtils.mv(new_rpm, target_dir)
        end
      end
    end
  end
end
