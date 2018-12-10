require 'simp/utils'
require 'simp/rpm/errors'

module Simp; end
module Simp::Rpm; end


# An Simp::Rpm::PackageInfo instance represents RPM metadata extracted
# from an RPM.
class Simp::Rpm::PackageInfo

  # Constructs a new Simp::Rpm::PackageInfo from an RPM file.
  #
  # This object provides getters for key metadata extracted from rpm_file.
  # It also provides an RPM version comparator.
  #
  # +rpm_file+:: Name of the RPM file
  # +verbose+::  Whether to log debug information.
  #
  # @raises ArgumentError if rpm_file cannot be read
  def initialize(rpm_file, verbose = false)
    unless rpm_file and File.readable?(rpm_file)
      raise ArgumentError.new("ERROR: Simp::Rpm::PackageInfo unable to read '#{rpm_file}'")
    end

    @rpm_file = File.expand_path(rpm_file)
    @rpm_name = File.basename(@rpm_file)
    @verbose = verbose

    # use a lazy assignment so that we only query the RPM package
    # for the info actually needed
    @basename = nil
    @version = nil
    @release = nil
    @full_version = nil
    @name = nil
    @arch = nil
    @signature = nil
  end

  # @returns The machine architecture of the package
  #
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def arch
    extract_basic_info if @arch.nil?
    @arch
  end

  # @returns The name of the package (as it would be queried in yum)
  #
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def basename
    extract_basic_info if @basename.nil?
    @basename
  end

  # @returns The full version of the package: [version]-[release]
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def full_version
    extract_basic_info if @full_version.nil?
    @full_version
  end

  # @returns Hash of the package metadata
  # @raises Simp::Rpm::QueryError if an RPM query fails
  def info
     {
       :basename     => basename,
       :version      => version,
       :release      => release,
       :full_version => full_version,
       :name         => name,
       :arch         => arch,
       :signature    => signature,
       :rpm_name     => rpm_name
     }
  end

  # @returns The full name of the package: [basename]-[full_version]
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def name
    extract_basic_info if @name.nil?
    @name
  end

  # @returns Whether the current RPM package is newer than other_rpm.
  #   Returns true if other_rpm is nil or empty.
  #
  # +other_rpm+:: Other package filename.  When non-empty, must end in '.rpm'.
  #
  # @raises ArgumentError if other_rpm is not empty and does not end in '.rpm'.
  # @raises RuntimeError if version comparison cannot be made
  def newer?(other_rpm)
    return true if other_rpm.nil? || other_rpm.empty?

    unless other_rpm.match(%r(\.rpm$))
      msg = "ERROR: Simp::Rpm::PackageInfo.newer? passed invalid RPM name '#{other_rpm}'"
      raise ArgumentError.new(msg)
    end

    if File.readable?(other_rpm)
      other_full_version = Simp::Rpm::PackageInfo.new(other_rpm, @verbose).full_version
    else
      # determine RPM info in a hacky way, ASSUMING, the other RPM has the
      # same basename and arch
      other_full_version = other_rpm.gsub(/#{basename}\-/,'').gsub(/.rpm$/,'')
      package_arch = arch
      unless package_arch.nil? or package_arch.empty?
        other_full_version.gsub!(/.#{package_arch}/,'')
      end
    end

    begin

      return Gem::Version.new(full_version) > Gem::Version.new(other_full_version)

    rescue ArgumentError, NoMethodError
      msg = "ERROR: Simp::Rpm::PackageInfo::newer? could not compare RPMs '#{rpm_name}' and '#{other_rpm}'"
      raise msg
    end
  end

  # @returns The release version of the package
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def release
    extract_basic_info if @release.nil?
    @release
  end

  # @returns The full name of the RPM
  def rpm_name
    @rpm_name
  end

  # @returns The signature key of the package, if it exists or nil
  #   otherwise. Will always be nil when the information for this
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def signature
    extract_signature if @signature.nil?
    if @signature == :none
      return nil
    else
      return @signature
    end
  end

  # @returns The version of the package
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def version
    extract_basic_info if @version.nil?
    @version
  end

  private

  # Extracts basename, version, release and arch from the RPM file and
  # uses that info to construct the full version (version with release)
  # an package name (basename with full version) metadata.
  #
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def extract_basic_info
    version_query = %Q(rpm -q --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\\n')
    version_query += " -p #{@rpm_file}"
    version_results = Simp::Utils::execute(version_query, @verbose)

    if version_results[:exit_status] != 0
      msg =<<-EOE
#{Simp::Utils::indent('Error getting RPM info:', 2)}
#{Simp::Utils::indent(version_results[:stderr].strip, 5)}
#{Simp::Utils::indent("Run '#{version_query.gsub("\n",'\\n')}' to recreate the issue.", 2)}
      EOE
      raise Simp::Rpm::QueryError.new(msg)
    end

    parts = version_results[:stdout].strip.split(' ')
    @basename, @version, @release, @arch = parts

    # Construct other helpful info from that metadata
    @full_version = "#{@version}-#{@release}"
    @name = "#{@basename}-#{@full_version}"

    if @verbose
      puts "== Simp::Rpm::PackageInfo basic metadata for #{@rpm_name}"
      [ 'basename', 'version', 'release', 'full_version', 'name', 'arch',
        'signature' ].each do |meta|
        eval("puts \"  #{meta} = \#{@#{meta}}\"")
      end
    end
  end

  # Extracts any signature from the RPM file
  # @raises Simp::Rpm::QueryError if the RPM query fails
  def extract_signature
    signature_query = %Q(rpm -q --queryformat '%|DSAHEADER?{%{DSAHEADER:pgpsig}}:{%|RSAHEADER?{%{RSAHEADER:pgpsig}}:{%|SIGGPG?{%{SIGGPG:pgpsig}}:{%|SIGPGP?{%{SIGPGP:pgpsig}}:{(none)}|}|}|}|\\n')
    signature_query += " -p #{@rpm_file}"
    signature_results = Simp::Utils::execute(signature_query, @verbose)

    if signature_results[:exit_status] != 0
      msg =<<-EOE
#{Simp::Utils::indent('Error getting RPM signature:', 2)}
#{Simp::Utils::indent(signature_results[:stderr].strip, 5)}
#{Simp::Utils::indent("Run '#{signature_query.gsub("\n",'\\n')}' to recreate the issue.", 2)}
      EOE
      raise Simp::Rpm::QueryError.new(msg)
   else
     if signature_results[:stdout].include?('none')
       @signature = :none
     else
       @signature = signature_results[:stdout].strip
     end
   end

    if @verbose
      puts "== Simp::Rpm::PackageInfo signature for #{@rpm_name}"
      puts "  signature = #{@signature}"
    end
  end

end
