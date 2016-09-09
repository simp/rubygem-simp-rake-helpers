require 'spec_helper'
require 'simp/build/mock'
require 'tmpdir'

describe Simp::Build::Mock do

  before :all do
    @resultdir_path = Dir.mktmpdir('rspec_simp_build_mock')

    dir          = File.expand_path( 'files', File.dirname( __FILE__ ) )
    @spec_file   = File.join( dir, 'testpackage.spec' )
    @m_spec_file = File.join( dir, 'testpackage-multi.spec' )
    @rpm_file    = File.join( dir, 'testpackage-1-0.noarch.rpm' )
  end

  let :m do
    m = Simp::Build::Mock.new('epel-7-x86_64', resultdir_path, 'xxx')
    m.auto_init = false
    m
  end

  let :test_files_path do
    File.expand_path( 'files',  File.dirname(__FILE__) )
  end

  let :resultdir_path do
    @resultdir_path
  end

  describe '#initialize' do
    it 'can init' do
      expect( Simp::Build::Mock.new('epel-7-x86_64', resultdir_path).class ).to be Simp::Build::Mock
    end
  end

  describe '#mock_cmd' do
    it "constructs default arguments correctly" do
      answer = [
         '/usr/bin/mock',
         '--uniqueext=xxx',
         '--no-cleanup-after',
         '--no-clean',
         "--resultdir=#{resultdir_path}",
         '--disable-plugin=package_state',
         '--root=epel-7-x86_64',
      ]
      expect( m.mock_cmd ).to eq answer
    end

    it "constructs arguments correctly when :verbose" do

      m.verbose = :verbose
      m.mock_offline = true
      answer = [
        '/usr/bin/mock',
         '--uniqueext=xxx',
         '--offline',
         '--verbose',
         '--no-cleanup-after',
         '--no-clean',
         "--resultdir=#{resultdir_path}",
         '--disable-plugin=package_state',
         '--root=epel-7-x86_64',
      ]
      expect( m.mock_cmd ).to eq answer
    end
  end


  describe '#mock_configs' do
    let :mm do
      m.mock_config_dir = File.join(test_files_path, 'etc')
      m
    end

    it 'returns an accurate list' do
      expect( mm.mock_configs ).to eq ['epel-6-x86_64', 'epel-7-x86_64']
    end
  end


  describe '#validate_mock_environment' do
    it 'raises error on bad mock bin' do
      m.mock_bin = '%$^^$#^'
      expect{ m.validate_mock_environment }.to raise_error( RuntimeError )
    end

    it 'raises error on bad chroot' do
      m.mock_config_dir = File.join(test_files_path, 'etc.bad')
      expect{ m.validate_mock_environment }.to raise_error( RuntimeError )
    end
  end


  describe '#verbose=' do
    it "inits to :normal" do; expect( m.verbose ).to be(:normal); end
    it "doesn't accept nonsense" do
      expect{ m.verbose = :foo }.to raise_error( ArgumentError )
    end
    it "can set verbose=" do
      m.verbose = :verbose
      expect( m.verbose).to be :verbose
    end
  end

  describe '#sh' do
    let :mm do
      m.verbose = :silent
      m
    end

    it "can run shell commands that exit with the expected codes" do
      status = mm.sh ['true' '>' '/dev/null']
      expect( status.success? ).to be true

      status = mm.sh ['false' '>' '/dev/null']
      expect( status.success? ).to be false
    end
  end

  describe '#copyin' do
    let :mm do
      m = Simp::Build::Mock.new('epel-7-x86_64',resultdir_path)
      m.verbose = :silent
      m
    end

    it "copies in files" do
      f1 = File.join(test_files_path, 'buildsrpm_files', 'build')
      f2 = File.join(test_files_path, 'buildsrpm_files', 'testpackage.spec')
      mm.run("mkdir -p #{resultdir_path}")
      expect{ mm.copyin(f1,f2,resultdir_path) }.not_to raise_error
      expect( mm.run("test -f #{resultdir_path}/testpackage.spec").success? ).to be true
      expect( mm.run("test -d #{resultdir_path}/build").success? ).to be true
    end
  end

  describe '#copyout' do
    let :mm do
      m = Simp::Build::Mock.new('epel-7-x86_64',resultdir_path)
      m.verbose = :silent
      m
    end

    it "copies out files" do
      f1 = File.join(resultdir_path, 'foo.test')
      mm.run("mkdir -p #{resultdir_path}; echo 1234 > #{f1}" )
      expect{ mm.copyout(f1,resultdir_path) }.not_to raise_error
      expect( File.file?(f1) ).to be true
    end
  end

  describe '#buildsrpm' do
    let :mm do
      m = Simp::Build::Mock.new('epel-7-x86_64',resultdir_path)
      m.verbose = :silent
      m
    end

    it "builds an SRPM" do
      pkg_dir = File.join(test_files_path, 'buildsrpm_files', 'build')
      spec_file = File.join(test_files_path, 'buildsrpm_files', 'testpackage.spec')
      srpm_file = File.join(resultdir_path, 'testpackage-1-0.src.rpm')
      mm.run("mkdir -p #{resultdir_path}")
      mm.copyin(spec_file,pkg_dir,resultdir_path)
      mm.run("chmod -R ugo+rwX #{resultdir_path}")

      expect( mm.buildsrpm(spec_file,pkg_dir).success? ).to be true
      expect( File.file?(srpm_file) ).to be true
    end
  end
  describe '#clean' do
    let :mm do
      m = Simp::Build::Mock.new('epel-7-x86_64',resultdir_path)
      m.verbose = :silent
      m
    end

    it "cleans the mock" do
      status = mm.clean
      expect( status.success? ).to be true
    end
  end

  after :all do
    FileUtils.rm_rf @resultdir_path
  end
end

