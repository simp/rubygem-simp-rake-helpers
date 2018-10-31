require 'simp/packer/iso_vars_json'
require 'spec_helper'
require 'tmpdir'
require 'json'

describe Simp::Packer::IsoVarsJson do
  DUMMY_CONTENT = 'Dummy text with known checksum'.freeze
  DUMMY_CHECKSUM = 'bd6eae40b2b18359f33332dd5b1a3dd5c9e885240c3d4907d6a1208cdafa0003'.freeze

  before do
    @tmp_dir = Dir.mktmpdir(File.basename(__FILE__))
    @iso = File.expand_path('fixture.iso', @tmp_dir)
    File.open(@iso, 'w') { |f| f.puts DUMMY_CONTENT }
    target_release = '6.3.0-Beta1'
    target_data = {
      'isos' => ['/path/to/CentOS-6.10-x86_64-bin-DVD1.iso', '/path/to/CentOS-6.10-x86_64-bin-DVD2.iso'],
      'build_command' => "bundle exec rake build:auto[/path/to,#{target_release}]",
      'os_version' => '6.10',
      'flavor' => 'CentOS'
    }
    @var_json = described_class.new(@iso, target_release, target_data, :silent => true)
  end

  after do
    FileUtils.remove_entry_secure @tmp_dir
  end

  let(:expected_checksum) { DUMMY_CHECKSUM }

  describe '#data' do
    it 'returns expected information for v1.0.0 format' do
      expect(@var_json.data).to include(
        'simp_vars_version' => '1.0.0',
        'box_distro_release'  => 'SIMP-6.3.0-Beta1-CentOS-6.10',
        'box_simp_release'    => '6.3.0-Beta1',
        'iso_checksum'        => DUMMY_CHECKSUM,
        'iso_checksum_type'   => 'sha256',
        'dist_os_flavor'      => 'CentOS',
        'dist_os_maj_version' => '6',
        'dist_os_version'     => '6.10',
        'dist_source_isos'    => 'CentOS-6.10-x86_64-bin-DVD1.iso:CentOS-6.10-x86_64-bin-DVD2.iso',
        'packer_src_type'     => 'simp-iso',
        'iso_builder'         => 'rubygem-simp-rake-helpers'
      )
    end
  end

  describe '#write' do
    before (:each) { @var_json.write }

    let(:json_file) { "#{File.basename(@iso, '.iso')}.json" }

    it 'writes a .json file with the same name as the .iso' do
      Dir.chdir(@tmp_dir) { |_dir| expect(File.exist?(json_file)).to be true }
    end

    it 'writes a .json file with expected data' do
      Dir.chdir(@tmp_dir) do |_dir|
        file_content = File.read(json_file)
        file_data = JSON.parse(file_content)
        expect(file_data['iso_checksum']).to eq expected_checksum
      end
    end
  end
end
