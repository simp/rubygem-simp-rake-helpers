class SIMPRpmDepException < StandardError; end
class SIMPRpmDepVersionException < StandardError; end

module Simp; end
module Simp::Rake; end
module Simp::Rake::Build; end
module Simp::Rake::Build::RpmDeps

  # returns array of RPM spec file 'Requires' lines derived
  # from a 'metadata.json' dependency version specification.
  #
  # +pkg+:: dependency package name
  # +dep_version+:: dependency version string from a 'metadata.json'
  #
  # raises SIMPRpmDepVersionException if the dependency version
  #   string cannot be parsed
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
  # the module_rpm_meta and module_metadata.  Only dependencies listed
  # in the module_rpm_meta hash will be included in the output. The
  # version requirements for each dependency will be pulled from
  # module_metadata.
  #
  # returns array of strings, each of which is an 'Obsoletes' or
  # 'Requires' line for use in an RPM spec file
  #
  # raises SIMPRpmDepException if any 'metadata.json' dependency
  #   version string from module_metadata cannot be parsed or a
  #   dependency specified in module_rpm_meta is not found in
  #   module_metadata
  #
  # +module_rpm_meta+:: module entry from the top-level
  #   'dependencies.yaml' file or nil, if no entry exists
  # +module_metadata+:: Hash containing the contents of the
  #   module's 'metadata.json' file
  def self.generate_custom_rpm_requires(module_rpm_meta, module_metadata)
    rpm_metadata_content = []

    if module_rpm_meta[:obsoletes]
      module_rpm_meta[:obsoletes].each_pair do |pkg, version|
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

    module_rpm_meta[:requires].each do |pkg|
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
  #
  # raises SIMPRpmDepException if any 'metadata.json' dependency
  #   version string from module_metadata cannot be parsed
  #
  # +module_metadata+:: Hash containing the contents of the
  #   module's 'metadata.json' file
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
  # 'Obsoletes' and/or 'Requires' lines for use in an RPM spec file.
  #
  # If the module_rpm_meta is not nil, the generated 'requires'
  # file will contain
  # * 'Obsoletes' lines for any obsoletes specified in the
  #   module_rpm_meta hash
  # * 'Requires' lines for any requires specified in the
  #   module_rpm_meta hash, where the versions for those
  #   dependencies are pulled from module_metadata.
  #
  # Otherwise, the generated 'requires' file will contain
  # "Requires" lines for each dependency specified module_metadata.
  #
  # raises SIMPRpmDepException if any 'metadata.json' dependency
  #   version string from module_metadata cannot be parsed or a
  #   dependency specified in module_rpm_meta is not found in
  #   module_metadata
  #
  # +dir+:: module root directory
  # +module_metadata+:: Hash containing the contents of the
  #   module's 'metadata.json' file
  # +module_rpm_meta+:: module entry from the top-level
  #   'dependencies.yaml' file or nil, if no entry exists
  def self.generate_rpm_requires_file(dir, module_metadata, module_rpm_meta)
    rpm_metadata_content = []
    if module_rpm_meta
      rpm_metadata_content = generate_custom_rpm_requires(module_rpm_meta, module_metadata)
    else
      rpm_metadata_content = generate_module_rpm_requires(module_metadata)
    end

    rpm_metadata_file = File.join(dir, 'build', 'rpm_metadata', 'requires')
    FileUtils.mkdir_p(File.dirname(rpm_metadata_file))
    File.open(rpm_metadata_file, 'w') do |fh|
      fh.puts(rpm_metadata_content.flatten.join("\n"))
      fh.flush
    end
  end

  # Generate 'build/rpm_metadata/release' file containing
  # release qualifier specified in the module_rpm_meta
  #
  # +dir+:: module root directory
  # +module_rpm_meta+:: module entry from the top-level
  #   'dependencies.yaml' file or nil, if no entry exists
  def self.generate_rpm_release_file(dir, module_rpm_meta)
   return unless (module_rpm_meta and module_rpm_meta[:release])

    rpm_release_file = File.join(dir, 'build', 'rpm_metadata', 'release')
    FileUtils.mkdir_p(File.dirname(rpm_release_file))
    File.open(rpm_release_file, 'w') do |fh|
      fh.puts('# release set by simp-core dependencies.yaml')
      fh.puts(module_rpm_meta[:release])
      fh.flush
    end
  end

  # Generate RPM metadata files
  # * 'build/rpm_metadata/requires' file containing RPM
  #   dependency/obsoletes information from the 'dependencies.yaml'
  #   and the module's 'metadata.json'; always created
  # * 'build/rpm_metadata/release' file containing RPM release
  #   qualifier from the 'dependencies.yaml'; only created if release
  #   qualifier if specified in the 'dependencies.yaml'
  #
  # raises SIMPRpmDepException if any 'metadata.json' dependency
  #   version string from module_metadata cannot be parsed or a
  #   dependency specified in module_rpm_meta is not found in
  #   module_metadata
  #
  # +dir+:: module root directory
  # +rpm_metadata+:: contents of top-level 'dependencies.yaml' file
  def self.generate_rpm_meta_files(dir, rpm_metadata)
    require 'json'

    metadata_json_file = File.join(dir, 'metadata.json')
    module_metadata = JSON.parse(File.read(metadata_json_file))
    module_name = module_metadata['name'].split(%r(-|/)).last
    module_rpm_meta = rpm_metadata[module_name]

    begin
      generate_rpm_requires_file(dir, module_metadata, module_rpm_meta)
    rescue SIMPRpmDepException => e
      fail "#{e.message} in #{metadata_json_file}"
    end

    generate_rpm_release_file(dir, module_rpm_meta)
  end
end
