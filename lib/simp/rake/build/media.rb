# frozen_string_literal: true

module Simp; end
module Simp::Rake; end
module Simp::Rake::Build; end

# Helpers for identifying vendor install media and building ISOs from them
module Simp::Rake::Build::Media
  # `.treeinfo` families that SIMP builds as `RedHat`
  RHEL_FAMILIES = %r{\A(Red Hat|RHEL|CentOS|AlmaLinux|Rocky|Oracle|Scientific)}i.freeze

  # Returns the `[general]` family, version and arch of a `.treeinfo` file
  # (the productmd INI file at the root of every RHEL-family install tree).
  # Missing values are nil.
  def self.read_treeinfo(file)
    require 'puppet'
    require 'puppet/util/inifile'

    ini = Puppet::Util::IniConfig::PhysicalFile.new(file)
    ini.read
    general = ini.get_section('general')
    h = general ? general.entries.to_h { |k, v| [k, v] } : {}

    ['family', 'version', 'arch'].to_h { |k| [k, h[k]&.strip] }
  end

  # The SIMP build distribution name for a `.treeinfo` family, or nil when
  # the family isn't RHEL-compatible. simp-core keeps one tree for all of
  # them, under `build/distributions/RedHat`.
  def self.baseos(family)
    'RedHat' if family.to_s.match?(RHEL_FAMILIES)
  end

  # Returns the arguments for `xorrisofs` (or `mkisofs`) to make a bootable
  # ISO of `dir`, booting with whichever El Torito images `dir` has:
  # `isolinux/isolinux.bin` for BIOS and `images/efiboot.img` for UEFI.
  def self.mkisofs_args(dir, label, output)
    bios = File.exist?(File.join(dir, 'isolinux', 'isolinux.bin'))
    uefi = File.exist?(File.join(dir, 'images', 'efiboot.img'))

    unless bios || uefi
      raise("Error: '#{dir}' has neither isolinux/isolinux.bin (BIOS) nor images/efiboot.img (UEFI) to boot from")
    end

    args = ['-A', label, '-V', label, '-volset', label,
            '-uid', '0', '-gid', '0', '-J', '-joliet-long', '-r', '-v',
            '-c', 'boot.cat']
    args += ['-b', 'isolinux/isolinux.bin', '-boot-load-size', '4', '-boot-info-table', '-no-emul-boot'] if bios
    args << '-eltorito-alt-boot' if bios && uefi
    args += ['-e', 'images/efiboot.img', '-no-emul-boot'] if uefi
    # A full path: xorrisofs doesn't match 'lost+found' as a bare name
    args + ['-m', 'TRANS.TBL', '-m', File.join(dir, 'lost+found'), '-o', output, dir]
  end
end
