require 'fileutils'
require 'find'
require 'simp/rpm/packageinfo'
require 'simp/rpm/specfileinfo'
require 'simp/rpm/specfiletemplate'
require 'simp/rpm/utils'

module Simp; end
module Simp::Rpm; end

class Simp::Rpm::Builder

  include Simp::Rpm::SpecFileTemplate

  # Directory into which generated artifacts will be placed
  DEFAULT_ARTIFACT_DIR        = 'dist'

  # Array of items in the component directory to exclude from
  # the source tar
  # TODO  Read .gitignore and/or .pmtignore files for this list?
  DEFAULT_EXCLUDE_LIST = [
    '.vagrant',
    'coverage',
    'dist',
    'junit',
    'log',
    'sec_results',
    'spec/fixtures/modules',
  ]

  # Array of items in the component directory to ignore when
  # checking if the tarball needs to be rebuilt
  DEFAULT_IGNORE_CHANGES_LIST = [
    'Gemfile.lock',
    "#{DEFAULT_ARTIFACT_DIR}/logs",
    "#{DEFAULT_ARTIFACT_DIR}/tmp",
    "#{DEFAULT_ARTIFACT_DIR}/*.rpm",
    "#{DEFAULT_ARTIFACT_DIR}/rpmbuild",
    'spec/fixtures/modules'
  ]

  # Array of items in the component directory that are required to
  # build RPMs using the LUA-based RPM templates (i.e., for Puppet
  # modules and simp-doc)
  DEFAULT_INFO_FILE_LIST = [
    'build/rpm_metadata/**',  # Puppet modules and simp-doc
    'CHANGELOG',              # Puppet modules and simp-doc
    'metadata.json'           # Puppet modules
  ]

  # Version of SIMP.  Used to select the LUA-based, RPM spec file
  # template, when the project does not contain a spec file in
  # <base_dir>/build.
  DEFAULT_SIMP_VERSION = '6.X'

  # +base_dir+::      Path to the project's directory
  #
  # +opts+::          Options hash that can contain the following keys:
  #  :exclude_list      Files/directories in base_dir to exclude from the
  #                     source tar.
  #                     *Defaults* to DEFAULT_EXCLUDE_LIST.
  #
  #  :ignore_changes_list  Files/directories in base_dir to ignore when
  #                     checking if the source tarball used to generate RPMs
  #                     needs to be rebuilt.
  #                     *Defaults* to DEFAULT_IGNORE_CHANGES_LIST if omitted.
  #
  #  :info_file_list    Files/directories in base_dir required to build RPMs
  #                     using the LUA-based RPM templates
  #                     *Defaults* to DEFAULT_INFO_FILE_LIST if omitted.
  #
  #  :no_signature_rebuild  Force a rebuild of the RPMs if existing RPMs are
  #                     of the appropriate version are present but unsigned.
  #                     *Defaults* to true if omitted.
  #
  #  :rpm_macros        Additional macros to define/undefine for proper
  #                     evaluation of the RPM spec file.
  #                     *Defaults* to [] if omitted.
  #
  #                     - Will be added to the macros used to tell rpmbuild where
  #                       the build tree is located  and how to the name the
  #                       generated RPM.
  #                     - Useful when the RPM is being built on a different OS
  #                       than the target for the RPM.  For example when the
  #                       OS-provided 'dist', 'el7', 'el6', and 'rhel' macros
  #                       don't match the target OS.
  #                     - Each entry is of the form <name:value> or <!name>,
  #                       where <name:value> specifies a macro to define and
  #                       <!name> specifies a macro to undefine.
  #
  #  :simp_version      Version of SIMP.  Used to select the LUA-based,
  #                     RPM spec file template, when the project does
  #                     not contain a spec file in <base_dir>/build.
  #                     *Defaults* to DEFAULT_SIMP_VERSION if omitted.
  #
  #  :verbosity         How much debug information to log, where 0 means no
  #                     debug logging.
  #                     *Defaults* to 0 if omitted.
  #
  def initialize(base_dir, opts = {})
    @base_dir = base_dir
    @exclude_list         = opts.fetch(:exclude_list, DEFAULT_EXCLUDE_LIST )
    @ignore_changes_list  = opts.fetch(:ignore_changes_list, DEFAULT_IGNORE_CHANGES_LIST )
    @info_file_list       = opts.fetch(:info_file_list, DEFAULT_INFO_FILE_LIST )
    @no_signature_rebuild = opts.fetch(:no_signature_rebuild, true)
    @simp_version         = opts.fetch(:simp_major_version, DEFAULT_SIMP_VERSION )
    @verbosity            = opts.fetch(:verbosity, 0)

    @pkg_name   = File.basename(@base_dir)
    @pkg_dir    = File.join(@base_dir, DEFAULT_ARTIFACT_DIR)
    @rpm_srcdir = "#{@pkg_dir}/rpmbuild/SOURCES"

    rpm_macros = [
      "buildroot:#{@pkg_dir}/rpmbuild/BUILDROOT",
      "builddir:#{@pkg_dir}/rpmbuild/BUILD",
      "_sourcedir:#{@rpm_srcdir}",
      "_rpmdir:#{@pkg_dir}",
      "_srcrpmdir:#{@pkg_dir}",
      "_build_name_fmt:%%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm",
      "pup_module_info_dir:#{@base_dir}"
    ]

    rpm_macros += opts.fetch(:rpm_macros, [])

    @rpm_options   = get_rpm_options(rpm_macros)
    @spec_file     = ensure_spec_file(opts[:simp_version])
    @spec_info     = Simp::Rpm::SpecFileInfo.new(@spec_file, rpm_macros, @verbosity > 1)
    @dir_name      = "#{@spec_info.basename}-#{@spec_info.version}"
    @full_pkg_name = "#{@dir_name}-#{@spec_info.release}"
    @tar_dest      = "#{@pkg_dir}/#{@full_pkg_name}.tar.gz"

    if @full_pkg_name =~ /UNKNOWN/
      # This can happen with spec files containing LUA (i.e., those for
      # Puppet modules and simp-doc), when the LUA is unable to extract
      # the package information from the supporting files (e.g., 
      # metadata.json or build/rpm_metadata/release)
      raise("Error: Could not determine package information for '#{@base_dir}'. Got '#{@full_pkg_name}'")
    end
  end

  def get_rpm_options(rpm_macros)
    rpm_options = []
    rpm_macros.each do |macro_def|
      if macro_def.include?(':')
        rpm_options << %(-D '#{macro_def.gsub(':', ' ')}')
      elsif macro_def[0] == '!'
        rpm_options << %(--undefine '#{macro_def[1..-1]}')
      else
        raise ArgumentError.new("ERROR: Simp::Rpm::Builder Invalid macro specification '#{macro_def}'")
      end
    end

    rpm_options << '-v' if @verbosity > 0
    rpm_options
  end

  def ensure_spec_file(simp_version)
    spec_file = nil
    local_specs = Dir.glob(File.join(@base_dir, 'build', '*.spec'))
    unless local_specs.empty?
      spec_file = local_specs.first
      if local_specs.size > 1
        $stderr.puts "WARNING:  Multiple spec files found for #{@base_dir}.  Using #{spec_file}"
      end
    else
      spec_template = spec_file_template(simp_version)
      pkg_tmp_dir = File.join(@pkg_dir, 'tmp')
      FileUtils.mkdir_p(pkg_tmp_dir, verbose: @verbosity > 1)
      spec_file = File.join(pkg_tmp_dir, "#{@pkg_name}.spec")
      FileUtils.cp(spec_template, spec_file)
      FileUtils.chmod(0640, spec_file, verbose: @verbosity > 1)
    end
    spec_file
  end

  #FIXME Explain:
  # (1) RPMs could already exist in the dist dir (built earlier or downloaded) and the RPMs are
  #     only rebuilt if needed
  # (2) Other files used in the build (e.g., build/rpm_metadata/requires) may be
  #     pre-populated.  (Do we need to explain this?)
  def build
    build_source_tar
    prep_rpm_source_dir
    build_source_rpms
    build_rpms
  end

  #  Build the tar package used to create the source RPM
  def build_source_tar
    FileUtils.mkdir_p(@pkg_dir, verbose: @verbosity > 1)
    target_dir = File.basename(@base_dir)

    Dir.chdir(%(#{@base_dir}/..)) do
      require_rebuild = false

      if File.exist?(@tar_dest)
        Find.find(target_dir) do |path|
          filename = File.basename(path)

          Find.prune if filename =~ /^\./
          Find.prune if ((filename == File.basename(@pkg_dir)) && File.directory?(path))

          to_ignore = @ignore_changes_list.map{|x| x = Dir.glob(File.join(@base_dir, x))}.flatten
          Find.prune if to_ignore.include?(File.expand_path(path))

          next if File.directory?(path)

          if require_rebuild?(@tar_dest, path)
            require_rebuild = true
            break
          end
        end
      else
        require_rebuild = true
      end

      if require_rebuild
        tar_cmd = %Q(tar --owner 0 --group 0 --exclude-vcs --exclude=#{@exclude_list.join(' --exclude=')} --transform='s/^#{@pkg_name}/#{@dir_name}/' -cpzf "#{@tar_dest}" #{@pkg_name})
        result = Simp::Utils::execute(tar_cmd, @verbosity > 1)
      end
    end
  end

  def prep_rpm_source_dir
    Dir.chdir(@pkg_dir) do

      # Copy in the materials required for the component builds
      # The following are required to build successful RPMs using
      # the LUA-based RPM template
      info_file_list = @info_file_list.map{|x| x = Dir.glob(File.join(@base_dir, x))}.flatten

      if @verbosity > 1
        puts "==== Simp::Rpm::Builder: base_dir: #{@base_dir}"
        puts "==== Simp::Rpm::Builder: rpm_options:\n #{@rpm_options.map{|x| "\n  #{x}"}.join}"
        puts "==== Simp::Rpm::Builder: info_file_list: #{info_file_list.map{|x| "\n  #{x}"}.join}"
      end

      FileUtils.mkdir_p(@rpm_srcdir, verbose: @verbosity > 1)
      info_file_list.each do |f|
        if File.exist?(f)
          FileUtils.cp_r(f, @rpm_srcdir, verbose: @verbosity > 1)
        end
      end

      # Link in any misc artifacts that got dumped into 'dist' by other code
      extra_deps = Dir.glob("*")
      extra_deps.delete_if{|x| x =~ /(\.rpm$|(^(rpmbuild|logs|tmp$)))/}

      Dir.chdir(@rpm_srcdir) do
        extra_deps.each do |dep|
#FIXME this doesn't detect file changes that need to be copied to @rpm_srcdir
          unless File.exist?(dep)
            FileUtils.cp_r("../../#{dep}", dep, verbose: @verbosity > 1)
          end
        end
      end
    end
  end

  def build_source_rpms
    Dir.chdir(@pkg_dir) do

      FileUtils.mkdir_p('logs', verbose: @verbosity > 1)
      FileUtils.mkdir_p('rpmbuild/BUILDROOT', verbose: @verbosity > 1)
      FileUtils.mkdir_p('rpmbuild/BUILD', verbose: @verbosity > 1)

      @srpms = [@full_pkg_name + '.src.rpm']
      if require_rebuild?(@srpms.first, @tar_dest)

        cmd = %(rpmbuild #{@rpm_options.join(' ')} -bs #{@spec_file} > logs/build.srpm.out 2> logs/build.srpm.err)
        puts "==== Simp:Rpm::Builder: SRPM BUILD:   #{cmd}" if @verbosity > 0
        %x(#{cmd})

        @srpms = File.read('logs/build.srpm.out').scan(%r(Wrote:\s+(.*\.rpm))).flatten

        if @srpms.empty?
          raise <<-EOM
Could not create SRPM for '#{@spec_info.basename}
  Error: #{File.read('logs/build.srpm.err')}
          EOM
        end
      end
    end
  end

  def build_rpms
    Dir.chdir(@pkg_dir) do

      # Collect the built, or downloaded, RPMs
      rpms = []

      @spec_info.packages
      expected_rpms = @spec_info.packages.map{|f|
        latest_rpm = Dir.glob("#{f}-#{@spec_info.version}*.rpm").select{|x|
          # Get all local RPMs that are not SRPMs
          x !~ /\.src\.rpm$/
        }.map{|x|
          # Convert them to objects
          x = Simp::Rpm::PackageInfo.new(x, @verbosity > 1)
        }.sort_by{|x|
          # Sort by the full version of the package and return the one
          # with the highest version
          Gem::Version.new(x.full_version)
        }.last

#FIXME use package_newer?
        if latest_rpm && (
            Gem::Version.new(latest_rpm.full_version) >=
            Gem::Version.new(@spec_info.full_version)
        )
          f = latest_rpm.rpm_name
        else
          f = @spec_info.rpm_name
        end
      }

      if expected_rpms.empty? || require_rebuild?(expected_rpms, @srpms)

        expected_rpms_data = expected_rpms.map{ |f|
          if File.exist?(f)
            f = Simp::Rpm::PackageInfo.new(f, @verbosity > 1)
          else
            f = nil
          end
        }

        require_rebuild = true

        # We need to rebuild if not *all* of the expected RPMs are present
        unless expected_rpms_data.include?(nil)
          # If all of the RPMs are signed, we do not need a rebuild
          require_rebuild = !expected_rpms_data.compact.select{|x| !x.signature}.empty?
        end

        if !require_rebuild
          # We found all expected RPMs and they all had valid signatures
          #
          # Record the existing RPM metadata in the output file
          rpms = expected_rpms
        else
          # Try a build
          cmd = %(rpmbuild #{@rpm_options.join(' ')} --rebuild #{@srpms.first} > logs/build.rpm.out 2> logs/build.rpm.err)
          puts "==== Simp::Rpm::Builder: #{cmd}" if @verbosity > 0
          result = %x(#{cmd})
          puts result if @verbosity > 1

          # If the build failed, it was probably due to missing dependencies
          unless $?.success?
            handle_missing_build_deps(@srpms)

            # Try it again!
            #
            # If this doesn't work, something we can't fix automatically is wrong
            cmd = %(rpmbuild #{@rpm_options.join(' ')} --rebuild #{@srpms.first} > logs/build.rpm.out 2> logs/build.rpm.err)
            puts "==== Simp::Rpm::Builder: #{cmd}" if @verbosity > 0
            result = %x(#{cmd})
            puts result if @verbosity > 1
          end

          rpms = File.read('logs/build.rpm.out').scan(%r(Wrote:\s+(.*\.rpm))).flatten - @srpms

          if rpms.empty?
            raise <<-EOM
  Could not create RPM for '#{@spec_info.basename}
Error: #{File.read('logs/build.rpm.err')}
            EOM
          end
        end

        # Prevent overwriting the last good metadata file
        raise %(Could not find any valid RPMs for '#{@spec_info.basename}') if rpms.empty?

        Simp::Rpm::Utils.create_rpm_build_metadata(File.expand_path(@base_dir), @srpms, rpms)
      end
    end
  end

  def handle_missing_build_deps(srpms)
    # Find the RPM build dependencies
    rpm_build_deps = %x(rpm -q -R -p #{srpms.first}).strip.split("\n")

    # RPM stuffs this in every time
    rpm_build_deps.delete_if {|x| x =~ /^rpmlib/}

    # See if we have the ability to install things
    unless Process.uid == 0
      unless %x(sudo -ln) =~ %r(NOPASSWD:\s+(ALL|yum( install)?))
        raise <<-EOM
Please install the following dependencies and try again:
#{rpm_build_deps.map{|x| x = "  * #{x}"}.join("\n")}
EOM
      end
    end

    rpm_build_deps.map! do |rpm|
      if rpm =~ %r((.*)\s+(?:<=|=|==)\s+(.+))
        rpm = "#{$1}-#{$2}"
      end

      rpm.strip
    end

    yum_install_cmd = %(yum -y install '#{rpm_build_deps.join("' '")}')
    unless Process.uid == 0
      yum_install_cmd = 'sudo ' + yum_install_cmd
    end
    puts "==== Simp::Rpm::Builder: #{yum_install_cmd}" if @verbosity > 0

    install_output = %x(#{yum_install_cmd} 2>&1)

    if !$?.success? || (install_output =~ %r((N|n)o package))
      raise <<-EOM
Could not run #{yum_install_cmd}
Error: #{install_output}
      EOM
    end
  end

  # Return True if any of the 'old' Array are newer than the 'new' Array
  def require_rebuild?(new, old)
    return true if ( Array(old).empty? || Array(new).empty?)

    Array(new).each do |new_file|
      return true unless File.exist?(new_file)

      return true unless FileUtils::uptodate?(new_file, Array(old))
    end

    return false
  end

end
