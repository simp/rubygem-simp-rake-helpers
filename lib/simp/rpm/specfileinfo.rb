require 'simp/utils'
require 'simp/rpm/specfiletemplate'

module Simp; end
module Simp::Rpm; end

class Simp::Rpm::QueryError < StandardError ; end

# An Simp::Rpm::SpecFileInfo instance represents RPM metadata extracted
# from an RPM spec file.
class Simp::Rpm::SpecFileInfo

  attr_reader :packages, :info_hash

  # Constructs a new Simp::Rpm::SpecFileInfo from an RPM spec file.
  #
  # This object provides getters for per-package key metadata extracted
  # from rpm_spec_file. It also provides an RPM version comparator.
  #
  # +rpm_spec_file+:: Name of the RPM spec file
  # +rpm_macros+::    Array of RPM macros to define/undefine for proper evaluation
  #                   of the RPM spec file.  Useful when the RPM spec file is being
  #                   evaluated on a different OS than the target for the RPM.
  #                   Each entry is of the form <name:value> or <!name>, where
  #                   <name:value> specifies a macro to define and <!name> specifies
  #                   a macro to undefine.
  # +verbose+::       Whether to log debug information.
  #
  # @raises ArgumentError if rpm_spec_file cannot be read or any of macro specifications
  #   in rpm_macros cannot be parse
  # @raises Simp::Rpm::QueryError if the RPM query for basic metadata fails
  #
  def initialize(rpm_spec_file, rpm_macros = [], verbose = false)
    unless rpm_spec_file and File.readable?(rpm_spec_file)
      raise ArgumentError.new("ERROR: Simp::Rpm::SpecFileInfo unable to read '#{rpm_spec_file}'")
    end
    @rpm_spec_file = File.expand_path(rpm_spec_file)

    @verbose = verbose

    args = ['rpm -q']
    rpm_macros.each do |macro_def|
      if macro_def.include?(':')
        args << %(-D '#{macro_def.gsub(':', ' ')}')
      elsif macro_def[0] == '!'
        args << %(--undefine '#{macro_def[1..-1]}')
      else
        raise ArgumentError.new("ERROR: Simp::Rpm::SpecFileInfo Invalid macro specification '#{macro_def}'")
      end
    end

    args << '-v' if @verbose
    args << "--specfile #{rpm_spec_file}"

    @rpm_cmd = args.join(' ')

    # key = package basename, value = Hash of metadata
    @info_hash = {}
    extract_basic_info

    @packages = @info_hash.keys

    # Extract the changelog on demand in changelog()
    @changelog = nil
  end

  # @returns The machine architecture of the package
  #
  # @raises ArgumentError if package is invalid
  def arch(package=@packages.first)
    valid_package?(package)
    @info_hash[package][:arch]
  end

  # @returns The name of the package (as it would be queried in yum)
  #
  # @raises ArgumentError if package is invalid
  def basename(package=@packages.first)
    valid_package?(package)
    @info_hash[package][:basename]
  end

  # @returns The changelog for all packages
  #
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def changelog
    extract_changelog if @changelog.nil?
    @changelog
  end

  # @returns The full version of the package: [version]-[release]
  #
  # @raises ArgumentError if package is invalid
  def full_version(package=@packages.first)
    valid_package?(package)
    @info_hash[package][:full_version]
  end

  # @returns Hash of the package metadata, excluding the changelog
  def info(package=@packages.first)
    valid_package?(package)
    @info_hash[package]
  end

  # @returns The full name of the package: [basename]-[full_version]
  # @raises ArgumentError if package is invalid
  def name(package=@packages.first)
    valid_package?(package)
    @info_hash[package][:name]
  end


  # Returns whether or not the current RPM (sub-)package is
  # newer than the passed RPM.
  def package_newer?(package, other_rpm)
    valid_package?(package)
    return true if other_rpm.nil? || other_rpm.empty?

    unless other_rpm.match(%r(\.rpm$))
      msg = "ERROR: Simp::Rpm::SpecFileInfo.package_newer? passed invalid RPM name '#{other_rpm}'"
      raise ArgumentError.new(msg)
    end

    if File.readable?(other_rpm)
      other_full_version = Simp::Rpm::PackageInfo.new(other_rpm, @verbose).full_version
    else
      # determine RPM info in a hacky way, ASSUMING, the other RPM has the
      # same basename and arch
      other_full_version = other_rpm.gsub(/#{package}\-/,'').gsub(/.rpm$/,'')
      package_arch = arch(package)
      unless package_arch.nil? or package_arch.empty?
        other_full_version.gsub!(/.#{package_arch}/,'')
      end
    end

    begin

      return Gem::Version.new(full_version(package)) > Gem::Version.new(other_full_version)

    rescue ArgumentError, NoMethodError
      msg = "ERROR: Simp::Rpm::SpecFileInfo::package_newer? could not compare RPMs '#{rpm_name(package)}' and '#{other_rpm}'"
      raise msg
    end
  end

  # @returns The release version of the package
  #
  # @raises ArgumentError if package is invalid
  def release(package=@packages.first)
    valid_package?(package)
    @info_hash[package][:release]
  end

  # @returns The full name of the RPM, [basename]-[version]-[release].[arch].rpm
  #   All SIMP-generated component RPMs follow this naming convention.
  #
  # @raises ArgumentError if package is invalid
  def rpm_name(package=@packages.first)
    valid_package?(package)
    @info_hash[package][:rpm_name]
  end

  # @returns The version of the package
  #
  # @raises ArgumentError if package is invalid
  def version(package=@packages.first)
    valid_package?(package)
    @info_hash[package][:version]
  end

  private


  # Extracts basename, version, release and arch for each package specified
  # in # the RPM spec file and uses that info to construct each package's full
  # version ([version]-[release]), package name ([basename]-[version]=[release])
  # and assumed RPM filename ([basename]-[version]-[release].[arch].rpm)
  # metadata.  All SIMP-generated component RPMs follow this RPM naming
  # convention.
  #
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def extract_basic_info
    version_query = %Q(#{@rpm_cmd} --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\\n')
    version_results = Simp::Utils::execute(version_query, @verbose)

    if version_results[:exit_status] != 0
      msg =<<-EOE
#{Simp::Utils::indent('Error getting RPM info:', 2)}
#{Simp::Utils::indent(version_results[:stderr].strip, 5)}
#{Simp::Utils::indent("Run '#{version_query.gsub("\n",'\\n')}' to recreate the issue.", 2)}
      EOE
      raise Simp::Rpm::QueryError.new(msg)
    end

    version_results[:stdout].strip.lines.each do |line|
      parts = line.split(' ')
      info = {}
      info[:basename], info[:version], info[:release], info[:arch] = parts

      # Construct other helpful info from that metadata
      info[:full_version] = "#{info[:version]}-#{info[:release]}"
      info[:name]         = "#{info[:basename]}-#{info[:full_version]}"
      info[:rpm_name]     = "#{info[:name]}.#{info[:arch]}.rpm"
      @info_hash[info[:basename]] = info
    end

    if @verbose
      puts "== Simp::Rpm::SpecFileInfo basic metadata for #{@rpm_spec_file}"
      @info_hash.each { |package, meta_hash| puts "  #{package}=#{meta_hash}" }
    end
  end

  def extract_changelog
    changelog_query = "#{@rpm_cmd} --changelog"
    changelog_results = Simp::Utils::execute(changelog_query, @verbose)

    if changelog_results[:exit_status] != 0
      msg =<<-EOE
#{Simp::Utils::indent('Error getting RPM info:', 2)}
#{Simp::Utils::indent(changelog_results[:stderr].strip, 5)}
#{Simp::Utils::indent("Run '#{changelog_query.gsub("\n",'\\n')}' to recreate the issue.", 2)}
      EOE
      raise Simp::Rpm::QueryError.new(msg)
    end

    @changelog = changelog_results[:stdout]

    if @verbose
      puts "== Simp::Rpm::SpecFileInfo changelog for #{@rpm_spec_file}"
      puts Simp::Utils::indent(@changelog, 2)
    end
  end

  def valid_package?(package)
    unless @packages.include?(package)
      raise ArgumentError.new("Simp::Rpm::SpecFileInfo '#{package}' is not a valid sub-package of #{@rpm_spec_file}")
    end
  end
end

class Simp::Rpm::TemplateSpecFileInfo < Simp::Rpm::SpecFileInfo

  include Simp::Rpm::SpecFileTemplate

  def initialize(component_dir, simp_version = nil, rpm_macros = [], verbose = false)
     spec_template = spec_file_template(simp_version)
     macros = rpm_macros.dup
     macros << "_sourcedir:#{component_dir}"
     super(spec_template, macros, verbose)
  end
end
