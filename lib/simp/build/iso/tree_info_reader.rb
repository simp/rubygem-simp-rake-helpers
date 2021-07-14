require 'puppet'
require 'puppet/util/inifile'

module Simp; end
module Simp::Build; end
module Simp::Build::Iso
  # Parses data from .treeinfo files. Supports pre-productmd and treeinfo 1.x.
  class TreeInfoReader
    PRE_PRODUCTMD_TREEINFO_VERSION = '0.0-pre-productmd'

    def initialize(treeinfo_file, target_arch: 'x86_64')
      File.exist?( treeinfo_file ) or fail("File does not exist: '#{treeinfo_file}'")

      @target_arch = target_arch
      @file = treeinfo_file
      @ini = Puppet::Util::IniConfig::PhysicalFile.new(@file)
      @ini.read
      @treeinfo_version = treeinfo_version
      @treeinfo_maj_version = treeinfo_version.split('.').first.to_i
    end

    # release version, for example: "21", "7.0", "2.1"
    # @return [String]
    def release_version
      @treeinfo_maj_version > 0 ? section('release')['version'] : section('general')['version']
    end

    # release short name, for example: "Fedora", "RHEL", "CentOS"
    def release_short_name
    # @return [String]
      @treeinfo_maj_version > 0 ? section('release')['short'] : section('general')['family']
    end

    # tree architecture, for example x86_64
    # @return [String]
    def tree_arch
      @treeinfo_maj_version > 0 ? section('tree')['arch'] : section('general')['arch']
    end

    # @return [Hash] collection of section hashes (k = name, v = k/v pairs)
    def sections
      @ini.sections.map{|s| [s.name, section(s.name)] }.to_h
    end

    # @param [String] name of ini section to read
    # @return [Hash] k/v pairs from ini [section] if it exists
    # @return [nil] if ini [section] doesn't exist
    def section(name)
      s = @ini.get_section(name) || return
      s.entries.grep(Array).to_h
    end

    # @return [Hash] data for all variants in [tree] section (treeinfo 1.x)
    def variants
      variant_uids = section('tree')['variants'].to_s.split(',')
      variant_uids.map { |uid| section("variant-#{uid}") }
    end

    # Determine .treeinfo version string
    # @return [String] if productmd format, treeinfo version
    # @return [String] if pre-productmd, PRE_PRODUCTMD_TREEINFO_VERSION
    # @raise [RuntimeError] if not in treeinfo format
    # @raise [RuntimeError] if productmd treeinfo version is higher than 1.x
    def treeinfo_version
      version = ''
      header = section('header')
      if header
        # productmd .treeinfo format (EL8+)
        version = header['version']
        unless version.to_s.split('.').first == '1'
          fail "ERROR: Unsupported productmd .treeinfo version: '#{version}': '#{@file}'"
        end
        warn "Detected productmd .treeinfo, version '#{verison}'" if @verbose
      else
        # pre-productmd .treeinfo format (EL7)
        unless section('general')
          fail "ERROR: Cannot parse: Not a pre-prouct .treeinfo format: '#{@file}' !"
        end
        version = PRE_PRODUCTMD_TREEINFO_VERSION
        warn 'Detected pre-productmd .treeinfo format (<= EL7)' if @verbose
      end
      version
    end

  end
end

