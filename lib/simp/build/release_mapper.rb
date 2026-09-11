# frozen_string_literal: true

require 'yaml'

module Simp; end

module Simp::Build
  class SIMPBuildException < StandardError; end

  # Maps a target SIMP release to the base OS ISOs required to build it.
  #
  # Reads a `release_mappings.yaml` (from simp-core's
  # `build/distributions/<distro>/<version>/<arch>/`) and matches a set of
  # candidate ISO files against the flavors known for the target release.
  #
  # Absorbed from the `simp-build-helpers` gem, which is no longer maintained
  # as a separate project.
  class ReleaseMapper
    attr_accessor :do_checksums, :verbose

    def initialize(target_release, mappings_file, do_checksums = false)
      @target_release   = target_release
      @mappings_file    = mappings_file
      @release_mappings = YAML.load_file(mappings_file)
      @target_data      = get_release_mappings_for_target(@target_release, @release_mappings)
      @do_checksums     = do_checksums
      @verbose          = false
    end

    def get_release_mappings_for_target(target_release, release_mappings)
      releases    = release_mappings.fetch('simp_releases')
      target_data = releases.fetch(target_release, false)

      unless target_data
        known = releases.keys.map { |x| "  - #{x}\n" }.join

        raise SIMPBuildException,
              "'#{target_release}' is not a recognized SIMP release.\n\n" \
              "## Recognized SIMP releases:\n#{known}\n\n"
      end

      target_data
    end

    # Given a path string of files or directories, return a list of .iso files
    #   - if all paths are bad, the result is an empty array
    #   - directories are scanned for .iso files
    def sanitize_iso_list(paths_string)
      paths_string.split(':').flat_map { |path|
        if File.directory?(path)
          Dir[File.join(path, '*.iso')]
        elsif File.file?(path)
          path
        else
          []
        end
      }.sort.uniq
    end

    # Given a list of isos: see if any match the complete set of ISOs for one
    # of the target_release's flavors.  If it matches, return a Hash containing
    # the flavor and the matched ISOs.  If they didn't match any known distros,
    # return nil
    #
    # Some of the `isos` lists might be superfluous
    def get_flavor(isos)
      iso_sizes   = isos.map { |iso| [iso, File.size(iso)] }.sort.to_h
      result      = false
      result_isos = []

      @target_data['flavors'].each do |flavor, data|
        sizes = data['isos'].map { |x| x['size'] }.sort
        next unless sizes.uniq == sizes & iso_sizes.values

        matched_isos = iso_sizes.select { |_iso, size| sizes.include?(size) }.keys
        result_isos  = matched_isos

        if @do_checksums || (sizes.uniq.size != sizes.size)
          checksums = data['isos'].map { |x| x['checksum'] }

          iso_checksums = matched_isos.to_h do |iso|
            puts "=== getting checksum of '#{iso}'" if @verbose

            [iso, `sha256sum "#{iso}"`.split(%r{ +}).first]
          end

          matched_isos = iso_checksums.select { |_iso, sum| checksums.include?(sum) }

          # The checksums did not account for every ISO this flavor expects, so
          # it is not a match.  Keep looking rather than falling through and
          # reporting the flavor with an empty ISO list.
          next unless matched_isos.values.uniq.size == checksums.uniq.size

          result      = flavor
          result_isos = matched_isos.keys.dup
          break
        end

        result = flavor
        break
      end

      return nil unless result

      @target_data['flavors'][result].merge({ 'flavor' => result, 'isos' => result_isos })
    end

    def autoscan_unpack_list(paths_string)
      iso_paths = sanitize_iso_list(paths_string)

      if iso_paths.empty?
        raise SIMPBuildException,
              "ERROR: No suitable ISOs found for target release '#{@target_release}' in '#{paths_string}'.\n\n" \
              "## Recognized SIMP ISOs for '#{@target_release}':\n\n#{recognized_isos}\n\n"
      end

      unpack_files = get_flavor(iso_paths)

      if unpack_files.nil?
        raise SIMPBuildException,
              "ERROR: No flavors for target release '#{@target_release}' found in '#{paths_string}'.\n\n" \
              "## Recognized SIMP ISOs for '#{@target_release}':\n\n#{recognized_isos(detailed: true)}\n\n"
      end

      unpack_files
    end

    private

    # Formatted list of the ISOs known for the target release, for use in error
    # messages.  When `detailed` is set, each ISO's expected size and checksum
    # are listed along with its name.
    def recognized_isos(detailed: false)
      max_iso_name_size = @target_data['flavors'].values.flat_map { |x| x['isos'] }.map { |x| x['name'].size }.max

      @target_data.fetch('flavors').map { |flavor, data|
        isos = data['isos'].map { |x|
          if detailed
            [
              "    - #{x['name'].ljust(max_iso_name_size)}",
              "       - size:     #{x['size']}",
              "       - checksum: #{x['checksum']}",
            ].join("\n")
          else
            "    - #{x['name']}"
          end
        }.join("\n")

        "  ### #{flavor}\n\n#{isos}\n\n"
      }.join
    end
  end
end
