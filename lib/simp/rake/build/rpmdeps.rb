class SIMPRpmDepException < StandardError; end
class SIMPRpmDepVersionException < StandardError; end

module Simp; end
module Simp::Rake; end
module Simp::Rake::Build; end
module Simp::Rake::Build::RpmDeps

  # returns array of RPM spec file 'Requires' lines derived
  # from a metadata.json dependency version specification.
  def self.get_version_requires(pkg, dep_version)
    requires = []
    if dep_version =~ /^\s*(\d+\.\d+\.\d+)\s*$/
      requires << "Requires: #{pkg} = #{$1}"
    else
      if dep_version.include?('x')
        dep_parts = dep_version.split('.')

        if dep_parts.count == 3
          dep_version = ">= #{dep_parts[0]}.#{dep_parts[1]}.0 < #{dep_parts[0].to_i + 1}.0.0"
        else
          dep_version = ">= #{dep_parts[0]}.0.0 < #{dep_parts[0].to_i + 1}.0.0"
        end
      end

      # metadata.json is a LOT more forgiving than the RPM spec file
      if dep_version =~ /^\s*(?:(?:([<>]=?)\s*(\d+\.\d+\.\d+))\s*(?:(<)\s*(\d+\.\d+\.\d+))?)\s*$/
        requires << "Requires: #{pkg} #{$1} #{$2}"
        requires << "Requires: #{pkg} #{$3} #{$4}" if $3
      else
        raise SIMPRpmDepVersionException.new
      end
    end
    requires
  end

  # Generate 'Obsoletes' and 'Requires' lines, from a combination of
  # the module_dep_info and module_metadata.  Only dependencies listed
  # in the module_dep_info hash will be included in the output. The
  # version requirements for each dependency will be pulled from
  # module_metadata.
  #
  # returns array of strings, each of which is an 'Obsoletes' or
  # 'Requires' line for use in an RPM spec file
  def self.generate_custom_rpm_requires(module_dep_info, module_metadata)
    rpm_metadata_content = []

    if module_dep_info[:obsoletes]
      module_dep_info[:obsoletes].each_pair do |pkg, version|
        module_version = module_metadata['version']

        # We don't want to add this if we're building an older
        # version or the RPM will be malformed
        if Gem::Version.new(module_version) >
          Gem::Version.new(version.split('-').first)

          rpm_metadata_content << "Obsoletes: #{pkg} > #{version}"
        else
          puts "Ignoring 'obsoletes' for #{pkg}: module version" +
           " #{module_version} from metadata.json is not >" +
           " obsolete version #{version}"
        end
      end
    end

    module_dep_info[:requires].each do |pkg|
      pkg_parts = pkg.split(%r(-|/))[-2..-1]

      # Need to cover all base cases
      short_names = [pkg_parts.join('/'), pkg_parts.join('-')]

      dep_info = module_metadata['dependencies'].select{ |dep|
        short_names.include?(dep['name'])
      }

      if dep_info.empty?
        err_msg = "Could not find #{short_names.first} dependency"
        raise SIMPRpmDepException.new(err_msg)
      else
        dep_version = dep_info.first['version_requirement']
      end

      begin
        rpm_metadata_content << get_version_requires(pkg, dep_version)
      rescue SIMPRpmDepVersionException => e
        err_msg = "Unable to parse #{short_names.first} dependency" +
          " version '#{dep_version}'"
        raise SIMPRpmDepException.new(err_msg)
      end
    end
    rpm_metadata_content.flatten
  end

  # Generate 'Requires' lines from each dependency specified in the
  # module_metadata hash
  #
  # returns array of strings, each of which is a 'Requires' line for
  # use in an RPM spec file
  def self.generate_module_rpm_requires(module_metadata)
    rpm_metadata_content = []
    module_metadata['dependencies'].each do |dep|
      pkg = "pupmod-#{dep['name'].gsub('/', '-')}"
      dep_version = dep['version_requirement']

      begin
        rpm_metadata_content << get_version_requires(pkg, dep_version)
      rescue SIMPRpmDepVersionException => e
        err_msg = "Unable to parse #{dep['name']} dependency" +
          " version '#{dep_version}'"
        raise SIMPRpmDepException.new(err_msg)
      end
    end

    rpm_metadata_content.flatten
  end

  # Generate 'build/rpm_metadata/requires' file containing
  # 'Obsoletes' and/or 'Requires' lines for use in an RPM spec file
  # from a combination of the 'metadata.json' file in dir and
  # the rpm_dependency_metadata
  # hash.
  #
  # If the rpm_dependency_metadata hash as an entry for the
  # module named in the 'metadata.json' file, the generated
  # 'requires' file will contain
  # * 'Obsoletes' lines for any obsoletes specified in the
  #   rpm_dependency_metadata hash
  # * 'Requires' lines for any requires specified in the
  #   rpm_dependency_metadata hash, where the versions for those
  #   dependencies are pulled from the 'metadata.json' file.
  #
  # Otherwise, the generated 'requires' file will contain
  # "Requires" lines for each dependency specified in the
  # 'metadata.json' file.
  def self.generate_rpm_requires_file(dir, rpm_dependency_metadata)
    require 'json'

    metadata_json_file = File.join(dir, 'metadata.json')
    module_metadata = JSON.parse(File.read(metadata_json_file))
    module_name = module_metadata['name'].split(%r(-|/)).last

    module_dep_info = rpm_dependency_metadata[module_name]
    rpm_metadata_content = []
    begin
      if module_dep_info
        rpm_metadata_content = generate_custom_rpm_requires(module_dep_info, module_metadata)
      else
        rpm_metadata_content = generate_module_rpm_requires(module_metadata)
      end
    rescue SIMPRpmDepException => e
      fail "#{e.message} in #{metadata_json_file}"
    end

    rpm_metadata_file = File.join(dir, 'build', 'rpm_metadata', 'requires')

    FileUtils.mkdir_p(File.dirname(rpm_metadata_file))
    File.open(rpm_metadata_file, 'w') do |fh|
      fh.puts(rpm_metadata_content.flatten.join("\n"))
      fh.flush
    end
  end
end
