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

  # Generate 'Obsoletes' lines from obsoletes_hash.
  #
  # returns array of strings, each of which is an 'Obsoletes' line for
  # use in an RPM spec file
  #
  # +obsoletes_hash+:: Hash containing package names and their versions
  #   this module obsoletes from the `dependencies.yaml` file
  # +module_metadata+:: Hash containing the contents of the module's
  #   'metadata.json' file
  def self.generate_custom_rpm_obsoletes(obsoletes_hash, module_metadata)
    rpm_metadata_content = []

    obsoletes_hash.each_pair do |pkg, version|
      module_version = module_metadata['version']

      # We don't want to add this if we're building an older
      # version or the RPM will be malformed
      main_version, release = version.split('-')
      release = '0' unless release
      release = release.to_i

      if Gem::Version.new(module_version) > Gem::Version.new(main_version)
        rpm_metadata_content << "Obsoletes: #{pkg} < #{main_version}-#{release}.obsolete"
        rpm_metadata_content << "Provides: #{pkg} = #{main_version}-#{release}.obsolete"
      else
        puts "Ignoring 'obsoletes' for #{pkg}: module version" +
         " #{module_version} from metadata.json is not >" +
         " obsolete version #{version}"
      end
    end
    rpm_metadata_content
  end

  # Generate 'Requires' lines, from a combination of the
  # module_rpm_meta and module_metadata.  Only dependencies listed
  # in the module_rpm_meta hash will be included in the output. The
  # version requirements for each dependency will be pulled from
  # module_metadata.
  #
  # returns array of strings, each of which is a 'Requires' line
  # for use in an RPM spec file
  #
  # raises SIMPRpmDepException if any 'metadata.json' dependency
  #   version string from module_metadata cannot be parsed or a
  #   dependency specified in module_rpm_meta is not found in
  #   module_metadata
  #
  # +requires_list+:: list of package this module should require
  #   from the 'dependencies.yaml'
  # +module_metadata+:: Hash containing the contents of the
  #   module's 'metadata.json' file
  def self.generate_custom_rpm_requires(requires_list, module_metadata)
    rpm_metadata_content = []

    requires_list.each do |pkg|
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
      rescue SIMPRpmDepVersionException
        err_msg = "Unable to parse #{short_names.first} dependency" +
          " version '#{dep_version}'"
        raise SIMPRpmDepException.new(err_msg)
      end
    end
    rpm_metadata_content.flatten
  end

  # Generate 'Requires' lines from each dependency specified in the
  # ext_deps_list array
  #
  # returns array of strings, each of which is a 'Requires' line
  # for use in an RPM spec file
  #
  # +ext_deps_list+:: Array of dependency Hashes.  The key of each
  #    dependency Hash the name of the dependency package and its value
  #    is a Hash containing the version info.  For example,
  #   [ 'package1' => { :min => '1.0.0' },
  #     'package2' => { :min => '3.1-1', :max => '4.0' } ]
  def self.generate_external_rpm_requires(ext_deps_list)
    requires = []

    ext_deps_list.each do |pkg_name, options|
      requires << "Requires: #{pkg_name} >= #{options[:min]}"
      if options[:max]
        requires << "Requires: #{pkg_name} < #{options[:max]}"
      end
    end
    requires
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
    # metadata.json should always contain dependencies list, even
    # if it is empty, but we'll safely handle that error case here
    if module_metadata['dependencies']
      module_metadata['dependencies'].each do |dep|
        pkg = "pupmod-#{dep['name'].gsub('/', '-')}"
        dep_version = dep['version_requirement']

        begin
          rpm_metadata_content << get_version_requires(pkg, dep_version)
        rescue SIMPRpmDepVersionException
          err_msg = "Unable to parse #{dep['name']} dependency" +
            " version '#{dep_version}'"
          raise SIMPRpmDepException.new(err_msg)
        end
      end
    end

    rpm_metadata_content.flatten
  end

  # Check to see if the contents of the requires file match the new requires info
  #
  # +new_requires_info+:: The new requires metadata Array
  # +rpm_requires_file+:: The path to the module requires file
  def self.rpm_requires_up_to_date?(new_requires, rpm_requires_file)
    return false unless File.exist?(rpm_requires_file)

    rpm_requires_content = File.read(rpm_requires_file).lines.map(&:strip) - ['']

    return (new_requires.flatten - rpm_requires_content).empty?
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
  # * 'Requires' line(s) for any external dependencies specified
  #   in the module_rpm_meta hash.
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
    if module_rpm_meta and module_rpm_meta[:obsoletes]
      rpm_metadata_content = generate_custom_rpm_obsoletes(module_rpm_meta[:obsoletes], module_metadata)
    end

    if module_rpm_meta and module_rpm_meta[:requires]
      rpm_metadata_content += generate_custom_rpm_requires(module_rpm_meta[:requires], module_metadata)
    else
      rpm_metadata_content += generate_module_rpm_requires(module_metadata)
    end

    if module_rpm_meta and module_rpm_meta[:external_dependencies]
      rpm_metadata_content += generate_external_rpm_requires(module_rpm_meta[:external_dependencies])
    end

    rpm_metadata_file = File.join(dir, 'build', 'rpm_metadata', 'requires')

    unless rpm_requires_up_to_date?(rpm_metadata_content, rpm_metadata_file)
      FileUtils.mkdir_p(File.dirname(rpm_metadata_file))
      File.open(rpm_metadata_file, 'w') do |fh|
        fh.puts(rpm_metadata_content.flatten.join("\n"))
        fh.flush
      end
    end
  end

  # Check to see if the contents of the release file match the new release info
  #
  # +new_release_info+:: The new release metadata string
  # +rpm_release_file+:: The path to the module release file
  def self.release_file_up_to_date?(new_release_info, rpm_release_file)
    return false unless File.exist?(rpm_release_file)

    return File.read(rpm_release_file).strip == new_release_info.strip
  end

  # Generate 'build/rpm_metadata/release' file containing release qualifier
  # specified in the module_rpm_meta
  #
  # +dir+:: module root directory
  # +module_rpm_meta+:: module entry from the top-level
  #   'dependencies.yaml' file or nil, if no entry exists
  def self.generate_rpm_release_file(dir, module_rpm_meta)
   return unless (module_rpm_meta and module_rpm_meta[:release])

    rpm_release_file = File.join(dir, 'build', 'rpm_metadata', 'release')

    unless release_file_up_to_date?(module_rpm_meta[:release], rpm_release_file)
      FileUtils.mkdir_p(File.dirname(rpm_release_file))
      File.open(rpm_release_file, 'w') do |fh|
        fh.puts('# release set by simp-core dependencies.yaml')
        fh.puts(module_rpm_meta[:release])
        fh.flush
      end
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
