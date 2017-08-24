require 'simp/rake/build/pkg'
require 'spec_helper'
require 'yaml'

describe 'Simp::Rake::Build::Helpers#generate_rpm_requires' do
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
  let(:rpm_dependency_metadata) {
   YAML.load(File.read(File.join(files_dir, 'dependencies.yaml')))
  }
  
  before :each do
    @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
    FileUtils.cp_r(files_dir, @tmp_dir)
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  context 'managed node with a name change and all permutations of valid dependency specifications' do
    it 'should generate requires file with obsoletes and valid dependencies' do
      mod_dir = File.join(@tmp_dir, 'files', 'changed_name_mod')
      Simp::Rake::Build::generate_rpm_requires(mod_dir,
        rpm_dependency_metadata)

      requires_file = File.join(mod_dir, 'build', 'rpm_metadata', 'requires')
      expect(File.exist?(requires_file)).to be true
      expected = <<EOM
Obsoletes: pupmod-oldowner-changed_name_mod > 2.5.0-2016.1
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
    end
  end

  context 'managed node with a subset of metadata.json dependencies' do
    it 'should generate requires file with dependencies only from dependencies.yaml' do
      mod_dir = File.join(@tmp_dir, 'files', 'managed_mod')
      Simp::Rake::Build::generate_rpm_requires(mod_dir,
        rpm_dependency_metadata)

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
EOM
      actual = IO.read(requires_file)
      expect(actual).to eq expected
    end
  end

  context 'unmanaged node' do
    it 'should leave existing requires file untouched' do
      mod_dir = File.join(@tmp_dir, 'files', 'unmanaged_mod')
      Simp::Rake::Build::generate_rpm_requires(mod_dir,
        rpm_dependency_metadata)

      expected = IO.readlines(File.join(files_dir, 'unmanaged_mod',
        'build', 'rpm_metadata', 'requires'))
      actual = IO.readlines(File.join(mod_dir, 'build', 'rpm_metadata', 'requires'))
      expect(actual).to eq expected
    end
  end

  context 'ignores obsoletes when version obsoleted is newer than this version' do
    it 'should generate requires file with no obsoletes' do
      mod_dir = File.join(@tmp_dir, 'files', 'obsoletes_too_new_mod')
      Simp::Rake::Build::generate_rpm_requires(mod_dir,
        rpm_dependency_metadata)

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
      expect { Simp::Rake::Build::generate_rpm_requires(mod_dir,
        rpm_dependency_metadata) }.to raise_error(err_msg)
    end
  end

  context 'malformed dependency version' do
    it 'should fail when dep in depedencies.yaml is not found in metadata.json' do
      mod_dir = File.join(@tmp_dir, 'files', 'malformed_dep_meta_mod')
      err_msg = "Unable to parse foo1/bar1 dependency version '1.0.0.1' in #{mod_dir}/metadata.json"
      expect { Simp::Rake::Build::generate_rpm_requires(mod_dir,
        rpm_dependency_metadata) }.to raise_error(err_msg)
    end
  end
end
