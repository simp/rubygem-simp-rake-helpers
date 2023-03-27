require 'spec_helper'
require 'simp/build/release_mapper'

describe Simp::Build::ReleaseMapper do
  before :each do
    @mappings_path = File.expand_path( 'files/release_mappings.yaml', File.dirname(__FILE__) )
    @mapper        = Simp::Build::ReleaseMapper.new( '5.1.X', @mappings_path )
  end

  let :iso_paths do
    pwd = File.expand_path( 'files/fake_isos', File.dirname(__FILE__) )
    {
      'c7-64' => File.join(pwd, 'CentOS-7-x86_64-DVD-1511.iso'),
      'r7-64' => File.join(pwd, 'RedHat-7.2-x86_64-DVD.iso'),
      'c7-64-1503-1' => File.join(pwd, 'CentOS-7-x86_64-DVD-1503-01.iso'),
      'c67-64-1' => File.join(pwd, 'CentOS-6.7-x86_64-bin-DVD1.iso'),
      'c67-64-2' => File.join(pwd, 'CentOS-6.7-x86_64-bin-DVD2.iso'),
      'bad'   => File.join(pwd, 'this', 'path', 'should', 'fail'),
      'c67-false-positive' => File.join(pwd, 'CentOS-6.7-false-positive.iso'),
    }
  end

  describe '#initialize' do
    it 'runs without errors' do
      expect{ Simp::Build::ReleaseMapper.new( '5.1.X', @mappings_path ) }.to_not raise_error
    end
  end

  describe '#sanitize_iso_list' do
    it 'returns a 1-element list given a valid file' do
      list = @mapper.sanitize_iso_list(iso_paths['c7-64'])
      expect( list ).to be_a(Array)
      expect( list.size ).to eq 1
    end

    it 'returns a 2-element list given two valid files (delimited by  ":")' do
      list = @mapper.sanitize_iso_list(
        [iso_paths['c67-64-1'],iso_paths['c67-64-2']].join(':')
      )
      expect( list ).to be_a(Array)
      expect( list.size ).to eq 2
    end

    it 'returns a list with one iso given the file' do
      list = @mapper.sanitize_iso_list(iso_paths['c7-64'])
      expect( list ).to be_a(Array)
      expect( list.select{ |x| x =~ /.iso/ }.size ).to eq list.size
    end

    it 'returns a list of isos in a directory' do
      list = @mapper.sanitize_iso_list( File.dirname iso_paths['c7-64'])
      expect( list ).to be_a(Array)
      expect( list.select{ |x| x =~ /.iso/ }.size ).to eq list.size
    end

    it 'returns an empty list for a non-existent path' do
      list = @mapper.sanitize_iso_list( iso_paths['bad'] )
      expect( list ).to be_a(Array)
      expect( list ).to be_empty
    end

    it 'returns an empty list for an empty directory' do
      list = @mapper.sanitize_iso_list(File.expand_path('files/fake_isos_empty',File.dirname(__FILE__)))
      expect( list ).to be_a(Array)
      expect( list ).to be_empty
    end
  end

  describe '#get_flavor' do
    it 'detects CentOS flavor for known file' do
      list = [ iso_paths['c7-64'] ]
      data = @mapper.get_flavor(list)
      expect( data['flavor'] ).to eq('CentOS')
      expect( data['isos'] ).to eq( list )
    end

    it 'detects RedHat flavor for known file' do
      list = [ iso_paths['r7-64'] ]
      data = @mapper.get_flavor(list)
      expect( data['flavor'] ).to eq('RedHat')
      expect( data['isos'] ).to eq( list )
    end

    it 'detects RedHat flavor and correct ISO from multiple files' do
      list = [ iso_paths['c67-64-1'], iso_paths['c67-64-2'], iso_paths['r7-64'] ]
      data = @mapper.get_flavor(list)
      expect( data['flavor'] ).to eq('RedHat')
      expect( data['isos'] ).to eq( [iso_paths['r7-64']] )
    end

    it 'detects CentOS flavor and correct ISOs from multiple files' do
      mapper = Simp::Build::ReleaseMapper.new( '4.2.X', @mappings_path )
      list = [ iso_paths['c67-64-1'], iso_paths['c67-64-2'], iso_paths['r7-64'] ]
      data = mapper.get_flavor(list)
      expect( data['flavor'] ).to eq('CentOS')
      expect( data['isos'] ).to eq( [iso_paths['c67-64-1'],  iso_paths['c67-64-2']] )
    end

    it 'returns nil when unable to detect a known flavor' do
      list = [ iso_paths['c67-64-1'], iso_paths['c67-64-2'] ]
      expect( @mapper.get_flavor(list) ).to be_nil
    end

    it 'detects CentOS flavor when checksums are enabled' do
      mapper = Simp::Build::ReleaseMapper.new( '4.2.X', @mappings_path, true )
      list = [ iso_paths['c67-64-1'], iso_paths['c67-64-2'], iso_paths['c67-false-positive'] ]
      expect( mapper.get_flavor(list)['flavor'] ).to eq('CentOS')
    end
  end


  describe '#autoscan_unpack_list' do
    it 'autodetects 5.1.X unpack ISO from multiple directories' do
      list = [ File.dirname(iso_paths['c7-64']),
               File.expand_path('files/fake_isos_empty',File.dirname(__FILE__)) ]
      path_string = list.join(':')
      data = @mapper.autoscan_unpack_list(path_string)
      expect( data ).to_not be_nil
      expect( data['flavor'] ).to eq('CentOS')
      expect( data['isos'] ).to eq [iso_paths['c7-64']]
    end

    it 'autodetects 4.2.X unpack ISOs from multiple directories' do
      list = [ File.dirname(iso_paths['c67-64-1']),
               File.expand_path('files/fake_isos_empty',File.dirname(__FILE__)) ]
      path_string = list.join(':')
      mapper = Simp::Build::ReleaseMapper.new( '4.2.X', @mappings_path, true )
      data = mapper.autoscan_unpack_list(path_string)
      expect( data ).to_not be_nil
      expect( data['flavor'] ).to eq('CentOS')
      expect( data['isos'].sort ).to eq [iso_paths['c67-64-1'],iso_paths['c67-64-2']]
    end

    it 'raises an error when no disks are found' do
      path_string = iso_paths['bad']
      expect{ @mapper.autoscan_unpack_list(path_string) }.to raise_error(Simp::Build::SIMPBuildException, /No suitable ISOs found/)
    end
    it "raises an error when no disks match the target's flavors" do
      path_string = [iso_paths['c67-64-1'], iso_paths['c67-64-2']].join(':')
      expect{ @mapper.autoscan_unpack_list(path_string) }.to raise_error(Simp::Build::SIMPBuildException, /No flavors for target release/)
    end
  end
end
