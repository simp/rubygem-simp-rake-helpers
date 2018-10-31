require 'simp/rake/helpers/version'
require 'digest'
require 'json'

module Simp
  module Packer
    # Write a `vars.json` file to accompany a SIMP ISO
    class IsoVarsJson
      # SemVer data version of file
      #
      #   (Starting at 1.0.0, because earlier formats didn't include versions)
      VARS_FORMAT_VERSION = '1.0.0'.freeze

      # @param file           [String] path to iso file
      # @param target_release [String] SIMP release to build (e.g., '6.X')
      #   This is a key from the build's `release_mappings.yaml` in simp-core
      # @param target_data    [Hash] Unpacked hash of isos and metadata
      #   The metadata is in the format returned by
      #   Simp::Build::ReleaseMapper#autoscan_unpack_list
      # @param opts           [Hash] extra options
      def initialize(iso, target_release, target_data, opts = {})
        @iso            = iso
        @target_release = target_release
        @target_data    = target_data
        @opts           = opts
        @opts[:silent] ||= false
      end

      # Returns a SHA256 checksum of iso file
      # @param file [String] path to file
      # @return [String] SHA256 sum of ISO
      def sha256sum(file)
        unless @opts[:silent]
          puts
          puts '=' * 80
          puts "#### Checksumming (SHA256) #{file}..."
          puts '=' * 80
          puts
        end

        Digest::SHA256.file(file).hexdigest
      end

      # Returns a versioned vars.json data structure
      # @return [Hash] vars data structure
      def data
        sum = sha256sum(@iso)
        box_distro_release = "SIMP-#{@target_release}-#{@target_data['flavor']}-#{@target_data['os_version']}"
        {
          'simp_vars_version'   => VARS_FORMAT_VERSION,
          'box_simp_release'    => @target_release,
          'box_distro_release'  => box_distro_release,
          'iso_url'             => @iso,
          'iso_checksum'        => sum,
          'iso_checksum_type'   => 'sha256',
          'new_password'        => 'suP3rP@ssw0r!suP3rP@ssw0r!suP3rP@ssw0r!',
          'output_directory'    => './OUTPUT',
          'dist_os_flavor'      => @target_data['flavor'],
          'dist_os_version'     => @target_data['os_version'],
          'dist_os_maj_version' => @target_data['os_version'].split('.').first,
          'dist_source_isos'    => @target_data['isos'].map { |x| File.basename(x) }.join(':'),
          'git_commit'          => %x(git rev-parse --verify HEAD).strip,
          'packer_src_type'     => 'simp-iso',
          'iso_builder'         => 'rubygem-simp-rake-helpers',
          'iso_builder_version' => Simp::Rake::Helpers::VERSION
        }
      end

      # Write data to a vars.json file for simp-packer to use
      #
      # @param file [String] path to vars.json file to write
      #   (Defaults to the same path as the .iso, with a `.json` extension)
      def write(vars_file = @iso.sub(%r{.iso$}, '.json'))
        unless @opts[:silent]
          puts
          puts '=' * 80
          puts '#### Writing packer vars data to:'
          puts "       '#{vars_file}'"
          puts '=' * 80
          puts
        end

        File.open(vars_file, 'w') { |f| f.puts data.to_json }
      end
    end
  end
end
