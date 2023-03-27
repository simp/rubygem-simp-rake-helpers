require 'yaml'

module Simp::Build
  class SIMPBuildException < Exception; end
  class ReleaseMapper
    attr_accessor :do_checksums, :verbose

    def initialize( target_release, mappings_file, do_checksums = false )
      @target_release   = target_release
      @mappings_file    = mappings_file
      @release_mappings = YAML.load_file( mappings_file )
      @target_data      = get_release_mappings_for_target( @target_release, @release_mappings )
      @do_checksums     = do_checksums
      @verbose          = false
    end


    def get_release_mappings_for_target( target_release, release_mappings )
      unless target_data = release_mappings
                             .fetch('simp_releases')
                             .fetch( target_release, false )

         raise SIMPBuildException, "'#{target_release}' is not a recognized SIMP release." +
                                   "\n\n## Recognized SIMP releases:\n" +
                                   release_mappings.fetch('simp_releases')
                                      .keys
                                      .map{|x| "  - #{x}\n"}
                                      .join +
                                   "\n\n"
      end
      target_data
    end


    # given a path string of files or directories, return a list of .iso files
    #   - if all paths are bad, the result is an empty arrays
    #   - directories are scanned for .iso files
    def sanitize_iso_list( paths_string )
      paths_string.split(':')
        .map do |path|
          if File.exists?( path )
            if File.directory? path
              Dir[File.join(path, '*.iso')]
            elsif File.file? path
              path
            else
              []
            end
          else
            []
          end
        end
        .flatten
        .sort
        .uniq
    end

    # Given a list of isos: see if any match the complete set of ISOs for one
    # of the target_release's flavors.  the target release.   If it matches,
    # return a Hash containing the flavor and the matched ISOs.  If they didn't
    # match any known distros, return nil
    #
    # Some of the `isos` lists might be superfluous
    def get_flavor( isos )
      iso_sizes = Hash[isos.map{|iso| [iso,File.size(iso)]}.sort]
      result = false
      result_isos = []
      @target_data['flavors'].each do |flavor,data|
        sizes = data['isos'].map{|x| x['size']}.sort
        next unless sizes.uniq == sizes & iso_sizes.values
        matched_isos = iso_sizes.select{|k,v| sizes.include?(v) }.keys
        result_isos  = matched_isos

        if @do_checksums || (sizes.uniq.size != sizes.size)
          result_isos  = []
          checksums = data['isos'].map{|x| x['checksum']}
          iso_checksums = Hash[matched_isos.map do |iso|
            puts "=== getting checksum of '#{iso}'" if @verbose
            sum = `sha256sum "#{iso}"`.split(/ +/).first
            [iso,sum]
          end]

          matched_isos = iso_checksums.select{|k,v| checksums.include?(v) }
          if ( matched_isos.values.map{|sum|  checksums.include? sum }
                           .all?{|x| x.class == TrueClass } ) &&
             ( matched_isos.values.uniq.size == checksums.uniq.size )
            result = flavor
            result_isos = matched_isos.keys.dup
            break
          end
        end
        result = flavor
        break
      end

      if result
        @target_data['flavors'][result]
          .merge({'flavor' => result})
          .merge({'isos' =>result_isos})
      else
        nil
      end
    end

    def autoscan_unpack_list( paths_string )
      iso_paths    = sanitize_iso_list( paths_string )

      if iso_paths.empty?
         raise SIMPBuildException,
           'ERROR: No suitable ISOs found for target release ' +
           "'#{@target_release}' in '#{paths_string}'.\n\n" +

           "## Recognized SIMP ISOs for '#{@target_release}:\n\n" +
           @target_data.fetch('flavors')
              .map{|flavor,data|
                "  ### #{flavor}\n\n" +
                data['isos'].map{|x| "    - #{x['name']}"}.join("\n") + "\n\n"
              }.join + "\n\n"
      end

      unpack_files = get_flavor( iso_paths )

      if unpack_files.nil?
         max_iso_name_size = [@target_data['flavors'].map{|k,v| v['isos']}].flatten.map{|x| x['name'].size}.max
         raise SIMPBuildException,
           "ERROR: No flavors for target release '#{@target_release}' found in '#{paths_string}'.\n\n" +
           "## Recognized SIMP ISOs for '#{@target_release}:\n\n" +
           @target_data.fetch('flavors')
              .map{|flavor,data|
                "  ### #{flavor}\n\n" +
                data['isos'].map{|x|
                  "    - #{x['name'].ljust(max_iso_name_size)}\n" +
                  "       - size:     #{x['size']}\n" +
                  "       - checksum: #{x['checksum']}"}.join("\n") + "\n\n"
              }.join + "\n\n"

      end

      unpack_files
    end
  end
end
