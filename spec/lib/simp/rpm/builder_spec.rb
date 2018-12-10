require 'simp/rpm/builder'
require 'spec_helper'
require 'tmpdir'

describe Simp::Rpm::Builder do
  before :all do
    @tmp_dir = Dir.mktmpdir(File.basename(__FILE__))
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )

    FileUtils.cp_r(File.join(@files_dir, 'asset-multi-macros'), @tmp_dir)
#    FileUtils.cp_r(File.join(@files_dir, 'pupmod-simp-testpackage'), @tmp_dir)
  end

  after :all do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe '.build_source_tar' do
    context 'No pre-existing source tar' do
    end

    context 'Pre-existing current source tar exists in dist' do
    end

    context 'Pre-existing old source tar exists in dist' do
    end

    context 'custom exclude_list' do
    end
  end

  describe '.build' do
    context 'Asset-type project' do
      context 'No pre-existing RPMs' do
      end

      context 'Pre-exising unsigned RPMs ' do
      end

      context 'Pre-existing current source RPM exists in dist' do
      end

      context 'Pre-existing old source RPM exists in dist' do
      end

      context 'Pre-existing RPMs of the same full version exist in dist' do
      end

      context 'Some but not all pre-existing RPMs of the same full version exist in dist' do
      end

      context 'Pre-existing RPMs with older full version exist in dist' do
      end

      context 'Pre-existing RPMs with newer full version exist in dist' do
      end

      context 'Pre-existing unsigned RPMs exist in dist' do
      end


      context 'custom ignore_changes_list' do
      end

      context 'rpm macros for target OS' do
      end

      context 'extra deps dumped into dist' do
      end

    end

    context 'Puppet module-type project' do
      context 'has build/rpm_metadata/* files' do
      end

    end

    context 'Build failures' do
      it 'Fails when an invalid macro is specified'
      context 'UNKNOWN package name extracted from metadata.json' do
      end

      pending 'Fails when missing deps and user does not have sudo privileges'
      pending 'Prompts user with sudo privileges to install deps'
    end

  end

end
