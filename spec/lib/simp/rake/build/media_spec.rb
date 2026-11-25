# frozen_string_literal: true

require 'simp/rake/build/media'
require 'spec_helper'
require 'tmpdir'

describe Simp::Rake::Build::Media do
  let(:files) { File.expand_path('files/treeinfo', __dir__) }

  describe '.read_treeinfo' do
    {
      'alma8' => { 'family' => 'AlmaLinux', 'version' => '8', 'arch' => 'x86_64' },
      'alma9' => { 'family' => 'AlmaLinux', 'version' => '9', 'arch' => 'x86_64' },
      'alma10' => { 'family' => 'AlmaLinux', 'version' => '10', 'arch' => 'x86_64' },
      'rocky9' => { 'family' => 'Rocky Linux', 'version' => '9.9', 'arch' => 'x86_64' },
      'stream9' => { 'family' => 'CentOS Stream', 'version' => '9', 'arch' => 'x86_64' },
      'centos7' => { 'family' => 'CentOS', 'version' => '7', 'arch' => 'x86_64' }
    }.each do |media, expected|
      it "reads #{media} media" do
        expect(described_class.read_treeinfo(File.join(files, media))).to eq expected
      end
    end

    it 'returns nils without a [general] section' do
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'treeinfo')
        File.write(file, "[tree]\narch = x86_64\n")
        expect(described_class.read_treeinfo(file)).to eq('family' => nil, 'version' => nil, 'arch' => nil)
      end
    end
  end

  describe '.baseos' do
    ['Red Hat Enterprise Linux', 'AlmaLinux', 'Rocky Linux', 'CentOS', 'CentOS Stream', 'Oracle Linux Server'].each do |family|
      it("maps #{family} to RedHat") { expect(described_class.baseos(family)).to eq 'RedHat' }
    end

    it('returns nil for Fedora') { expect(described_class.baseos('Fedora')).to be_nil }
    it('returns nil for no family') { expect(described_class.baseos(nil)).to be_nil }
  end

  describe '.mkisofs_args' do
    def tree(*boot_files)
      Dir.mktmpdir do |dir|
        boot_files.each do |f|
          FileUtils.mkdir_p(File.join(dir, File.dirname(f)))
          FileUtils.touch(File.join(dir, f))
        end
        yield dir
      end
    end

    let(:bios) { ['-b', 'isolinux/isolinux.bin', '-boot-load-size', '4', '-boot-info-table', '-no-emul-boot'] }
    let(:uefi) { ['-e', 'images/efiboot.img', '-no-emul-boot'] }

    it 'boots BIOS and UEFI when both images exist (EL8/EL9 media)' do
      tree('isolinux/isolinux.bin', 'images/efiboot.img') do |dir|
        args = described_class.mkisofs_args(dir, 'SIMP-7.0.0', 'out.iso')
        expect(args.each_cons(bios.size)).to include(bios)
        expect(args.each_cons(uefi.size + 1)).to include(['-eltorito-alt-boot'] + uefi)
        expect(args.each_cons(2)).to include(['-V', 'SIMP-7.0.0'], ['-m', File.join(dir, 'lost+found')], ['-o', 'out.iso'])
        expect(args.last).to eq dir
      end
    end

    it 'boots UEFI alone without an alternate boot entry' do
      tree('images/efiboot.img') do |dir|
        args = described_class.mkisofs_args(dir, 'SIMP-7.0.0', 'out.iso')
        expect(args).not_to include('-b', '-eltorito-alt-boot')
        expect(args.each_cons(uefi.size)).to include(uefi)
      end
    end

    it 'fails clearly with neither boot image (EL10 media)' do
      tree('images/eltorito.img') do |dir|
        expect { described_class.mkisofs_args(dir, 'SIMP-7.0.0', 'out.iso') }.to raise_error(%r{neither isolinux/isolinux.bin})
      end
    end
  end
end
