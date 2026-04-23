require 'simp/build/iso/tree_info_reader'
require 'spec_helper'

TREEINFO_FIXTURE_FILES_DIR = File.join(__dir__, 'files')

TREEINFO_EXPECTATIONS = {
  'treeinfo.CentOS7.0.2009-x86_64.ini' => {
    'short' => 'CentOS',
    'version' => '7',
    'arch' => 'x86_64',
  },
  'treeinfo.CentOS8.3.2011-x86_64.ini' => {
    'short' => 'CentOS',
    'version' => '8',
    'arch' => 'x86_64',
  },
  'treeinfo.Fedora-Server-21-x86_64.ini' => {
    'short' => 'Fedora',
    'version' => '21',
    'arch' => 'x86_64',
  },

}

FIXTURE_FILES = TREEINFO_EXPECTATIONS.map do |k,v|
  File.join( TREEINFO_FIXTURE_FILES_DIR, k )
end

describe Simp::Build::Iso::TreeInfoReader do
  let(:files_dir) { TREEINFO_FIXTURE_FILES_DIR }

  FIXTURE_FILES.each do |treeinfo_file|
    context "using .treeinfo data from '#{File.basename(treeinfo_file)}'" do
      let(:ini_file){ treeinfo_file }
      subject(:tree_info_reader){ Simp::Build::Iso::TreeInfoReader.new(ini_file) }

      describe '#initialize' do
        it 'succeeds with a valid .treeinfo file' do
          expect{ tree_info_reader }.to_not raise_error
        end
      end

      describe '#release_short_name' do
        let(:expected_value){ TREEINFO_EXPECTATIONS[File.basename(ini_file)]['short'] }
        it 'returns the expected name' do
          expect( tree_info_reader.release_short_name ).to eq expected_value
        end
      end

      describe '#release_version' do
        let(:expected_value){ TREEINFO_EXPECTATIONS[File.basename(ini_file)]['version'] }
        it 'returns the expected version' do
          expect( tree_info_reader.release_version ).to eq expected_value
        end
      end

      describe '#tree_arch' do
        let(:expected_value){ TREEINFO_EXPECTATIONS[File.basename(ini_file)]['arch'] }
        it 'returns the expected arch' do
          expect( tree_info_reader.tree_arch ).to eq expected_value
        end
      end
    end
  end
end
