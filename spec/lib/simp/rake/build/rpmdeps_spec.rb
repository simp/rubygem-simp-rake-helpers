require 'simp/rake/build/rpmdeps'
require 'spec_helper'
require 'tmpdir'
require 'yaml'

describe 'Simp::Rake::Build::RpmDeps#get_version_requires' do
  let(:pkg) { 'pupmod-foo-bar' }

  context 'with valid version specifications' do
    {
      "1.0.0"            => ['Requires: pupmod-foo-bar = 1.0.0'],
      "> 2.0.0"          => ['Requires: pupmod-foo-bar > 2.0.0'],
      "< 3.0.0"          => ['Requires: pupmod-foo-bar < 3.0.0'],
      ">= 4.0.0 < 5.0.0" => ['Requires: pupmod-foo-bar >= 4.0.0',
                             'Requires: pupmod-foo-bar < 5.0.0'],
      "5.x"              => ['Requires: pupmod-foo-bar >= 5.0.0',
                             'Requires: pupmod-foo-bar < 6.0.0'],
      "6.4.x"            => ['Requires: pupmod-foo-bar >= 6.4.0',
                             'Requires: pupmod-foo-bar < 7.0.0']
    }.each do |input, output|
      it do
        expect(Simp::Rake::Build::RpmDeps::get_version_requires(pkg, input)).to eq output
      end
    end
  end

  context 'with invalid version specifications' do
    it do
      expect{
        Simp::Rake::Build::RpmDeps::get_version_requires(pkg, '1.0.0.1')
      }.to raise_error(SIMPRpmDepVersionException)
    end

    # FIXME regex doesn't catch this
    pending do
      expect{
        Simp::Rake::Build::RpmDeps::get_version_requires(pkg, '<= 3.0.0')
      }.to raise_error(SIMPRpmDepVersionException)
    end
  end
end

describe 'Simp::Rake::Build::RpmDeps#generate_rpm_meta_files' do
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
  let(:rpm_metadata) {
   YAML.load(File.read(File.join(files_dir, 'dependencies.yaml')))
  }

  before :each do
    @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
    FileUtils.cp_r(files_dir, @tmp_dir)
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  context 'managed component with a name change (obsoletes)' do
    it 'should generate requires file with obsoletes' do
      mod_dir = File.join(@tmp_dir, 'files', 'changed_name_mod')
      Simp::Rake::Build::RpmDeps::generate_rpm_meta_files(mod_dir, rpm_metadata)

      requires_file = File.join(mod_dir, 'build', 'rpm_metadata', 'requires')
      expect(File.exist?(requires_file)).to be true
      expected = <<EOM
Obsoletes: pupmod-oldowner-changed_name_mod < 5.2.0
Provides: pupmod-oldowner-changed_name_mod = 5.2.0
Requires: pupmod-foo1-bar1 = 1.0.0
Requires: pupmod-foo2-bar2 > 2.0.0
Requires: pupmod-foo3-bar3 < 3.0.0
Requires: pupmod-foo4-bar4 >= 4.0.0
Requires: pupmod-foo4-bar4 < 5.0.0
Requires: pupmod-foo5-bar5 >= 5.0.0
Requires: pupmod-foo5-bar5 < 6.0.0
Requires: pupmod-foo6-bar6 >= 6.4.0
Requires: pupmod-foo6-bar6 < 7.0.0
EOM
      actual = IO.read(requires_file)
      expect(actual).to eq expected

      release_file = File.join(mod_dir, 'build', 'rpm_metadata', 'release')
      expect(File.exist?(release_file)).to be false
    end
  end

  context 'managed component with a subset of metadata.json deps, external deps and a release' do
    it 'should generate both a requires file and a release file from dependencies.yaml' do
      mod_dir = File.join(@tmp_dir, 'files', 'managed_mod')
      Simp::Rake::Build::RpmDeps::generate_rpm_meta_files(mod_dir, rpm_metadata)

      requires_file = File.join(mod_dir, 'build', 'rpm_metadata', 'requires')
      expect(File.exist?(requires_file)).to be true

      # expected should not include pupmod-puppetlabs-apt
      expected = <<EOM
Requires: pupmod-puppetlabs-stdlib >= 3.2.0
Requires: pupmod-puppetlabs-stdlib < 5.0.0
Requires: pupmod-ceritsc-yum >= 0.9.6
Requires: pupmod-ceritsc-yum < 1.0.0
Requires: pupmod-richardc-datacat >= 0.6.2
Requires: pupmod-richardc-datacat < 1.0.0
Requires: rubygem-puppetserver-toml >= 0.1.2
Requires: rubygem-puppetserver-blackslate >= 2.1.2.4-1
Requires: rubygem-puppetserver-blackslate < 2.2.0.0
EOM
      actual = IO.read(requires_file)
      expect(actual).to eq expected

      release_file = File.join(mod_dir, 'build', 'rpm_metadata', 'release')
      expect(File.exist?(release_file)).to be true
      expect(IO.read(release_file)).to match(/^2017.0$/)
    end
  end

  context 'managed component with only a release' do
    it 'should generate a release file from dependencies.yaml' do
      mod_dir = File.join(@tmp_dir, 'files', 'release_only_mod')
      Simp::Rake::Build::RpmDeps::generate_rpm_meta_files(mod_dir, rpm_metadata)

      requires_file = File.join(mod_dir, 'build', 'rpm_metadata', 'requires')
      expect(File.exist?(requires_file)).to be true

      expected = <<EOM
Requires: pupmod-puppetlabs-stdlib >= 3.2.0
Requires: pupmod-puppetlabs-stdlib < 5.0.0
EOM
      actual = IO.read(requires_file)
      expect(actual).to eq expected

      release_file = File.join(mod_dir, 'build', 'rpm_metadata', 'release')
      expect(File.exist?(release_file)).to be true
      expect(IO.read(release_file)).to match(/^2017.2$/)
    end
  end

  context 'unmanaged component' do
    it 'should replace requires file with metadata.json dependencies' do
      mod_dir = File.join(@tmp_dir, 'files', 'unmanaged_mod')
      Simp::Rake::Build::RpmDeps::generate_rpm_meta_files(mod_dir, rpm_metadata)

      # expected should overwritten with simply dependencies in order
      # they were listed in metadata.json
      expected = <<EOM
Requires: pupmod-puppetlabs-inifile >= 1.6.0
Requires: pupmod-puppetlabs-inifile < 2.0.0
Requires: pupmod-puppetlabs-puppetdb >= 5.1.2
Requires: pupmod-puppetlabs-puppetdb < 6.0.0
Requires: pupmod-puppetlabs-postgresql >= 4.8.0
Requires: pupmod-puppetlabs-postgresql < 5.0.0
Requires: pupmod-puppetlabs-stdlib >= 4.13.1
Requires: pupmod-puppetlabs-stdlib < 5.0.0
EOM
      requires_file = File.join(mod_dir, 'build', 'rpm_metadata', 'requires')
      expect(File.exist?(requires_file)).to be true

      actual = IO.read(requires_file)
      expect(actual).to eq expected

      original = IO.readlines(File.join(files_dir, 'unmanaged_mod',
        'build', 'rpm_metadata', 'requires'))
      expect(actual).to_not eq original

      release_file = File.join(mod_dir, 'build', 'rpm_metadata', 'release')
      expect(File.exist?(release_file)).to be false
    end
  end

  context 'ignores obsoletes when version obsoleted is newer than this version' do
    it 'should generate requires file with no obsoletes' do
      mod_dir = File.join(@tmp_dir, 'files', 'obsoletes_too_new_mod')
      Simp::Rake::Build::RpmDeps::generate_rpm_meta_files(mod_dir, rpm_metadata)

      requires_file = File.join(mod_dir, 'build', 'rpm_metadata', 'requires')
      expect(File.exist?(requires_file)).to be true

      # expected should not include pupmod-puppetlabs-apt
      expected = <<EOM
Requires: pupmod-foo1-bar1 = 1.0.0
Requires: pupmod-foo2-bar2 > 2.0.0
EOM
      actual = IO.read(requires_file)
      expect(actual).to eq expected
    end
  end

  context 'dependency from dependencies.yaml not found in metadata.json' do
    it 'should fail when dep in depedencies.yaml is not found in metadata.json' do
      mod_dir = File.join(@tmp_dir, 'files', 'unknown_dep_mod')
      err_msg = "Could not find oops/unknown dependency in #{mod_dir}/metadata.json"
      expect {
        Simp::Rake::Build::RpmDeps::generate_rpm_meta_files(mod_dir, rpm_metadata)
      }.to raise_error(err_msg)
    end
  end

  context 'malformed dependency version' do
    it 'should fail for managed component with invalid dep version in metadata.json' do
      mod_dir = File.join(@tmp_dir, 'files', 'malformed_dep_meta_mod')
      err_msg = "Unable to parse foo1/bar1 dependency version '1.0.0.1' in #{mod_dir}/metadata.json"
      expect {
        Simp::Rake::Build::RpmDeps::generate_rpm_meta_files(mod_dir, rpm_metadata)
      }.to raise_error(err_msg)
    end

    it 'should fail for unmanaged component with invalid dep version in metadata.json' do
      rpm_meta = rpm_metadata.dup
      rpm_meta ['malformed_dep_meta_mod'] = nil
      mod_dir = File.join(@tmp_dir, 'files', 'malformed_dep_meta_mod')
      err_msg = "Unable to parse foo1/bar1 dependency version '1.0.0.1' in #{mod_dir}/metadata.json"
      expect {
        Simp::Rake::Build::RpmDeps::generate_rpm_meta_files(mod_dir, rpm_meta)
      }.to raise_error(err_msg)
    end
  end
end
