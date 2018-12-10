require 'simp/rpm/specfileinfo'
require 'spec_helper'

describe Simp::Rpm::SpecFileInfo do
  before :all do

    files_dir = File.expand_path('files', File.dirname( __FILE__ ))

    @spec_file = File.join(files_dir, 'testpackage.spec')
    @sf_info = Simp::Rpm::SpecFileInfo.new(@spec_file)

    macros_spec_file = File.join(files_dir, 'testpackage-macros.spec')
    @sf_info_macros_default = Simp::Rpm::SpecFileInfo.new(macros_spec_file)

    macros = ['dist:.el6', 'el6:1', '!el7', 'rhel:6' ]
    @sf_info_macros_set = Simp::Rpm::SpecFileInfo.new(macros_spec_file, macros)

    multi_spec_file = File.join(files_dir, 'testpackage-multi.spec')
    @sf_info_multi = Simp::Rpm::SpecFileInfo.new(multi_spec_file)

    @lua_project_dir = File.join(files_dir, 'pupmod-simp-testpackage_lua')
    lua_spec_file = File.join(@lua_project_dir, 'build', 'pupmod-simp-testpackage_lua-0.0.2.spec')
    # LUA file (based on simp6.spec) won't work without the pupmod_module_info_dir macro,
    # unless you are in the module root directory
    lua_macros = [ "pup_module_info_dir:#{@lua_project_dir}" ]
    @sf_info_lua = Simp::Rpm::SpecFileInfo.new(lua_spec_file, lua_macros)

    @system_dist_macro = `rpm --eval '%{dist}'`.strip
    @system_dist_macro = '' if @system_dist_macro == '%{dist}'
  end

  describe 'class #initialize' do


    it 'fails to initialize when rpm spec file cannot be opened' do
      expect{ Simp::Rpm::SpecFileInfo.new('/does/not/exist/') }.to raise_error(ArgumentError)
    end

    it 'fails to initialize when RPM metadata query fails' do
      failed_result = {
          :exit_status => 1,
          :stdout      => '',
          :stderr      => 'RPM metadata query failed'
        }
        Simp::Utils.expects(:execute).returns(failed_result)
        expect { Simp::Rpm::SpecFileInfo.new(@spec_file) }.
          to raise_error(/RPM metadata query failed/)
    end
  end

  describe 'getter methods' do

    context '#arch' do
      it 'returns the package arch' do
        expect( @sf_info.arch ).to eq 'noarch'
        expect( @sf_info_macros_default.arch ).to eq 'noarch'
        expect( @sf_info_multi.arch ).to eq 'noarch'
        expect( @sf_info_multi.arch('testpackage') ).to eq 'noarch'
        expect( @sf_info_multi.arch('testpackage-doc') ).to eq 'noarch'
        expect( @sf_info_lua.arch ).to eq 'noarch'
      end

      it 'fails when invalid package specified' do
        expect { @sf_info.arch('oops') }.to raise_error(ArgumentError)
        expect { @sf_info_multi.arch('oops') }.to raise_error(ArgumentError)
      end
    end

    context '#basename' do
      it 'returns the package basename' do
        expect( @sf_info.basename ).to eq 'testpackage'
        expect( @sf_info_macros_default.basename ).to eq 'testpackage'
        expect( @sf_info_multi.basename ).to eq 'testpackage'
        expect( @sf_info_multi.basename('testpackage') ).to eq 'testpackage'
        expect( @sf_info_multi.basename('testpackage-doc') ).to eq 'testpackage-doc'
        expect( @sf_info_lua.basename ).to eq 'pupmod-simp-testpackage_lua'
      end

      it 'fails when invalid package specified' do
        expect { @sf_info.basename('oops') }.to raise_error(ArgumentError)
        expect { @sf_info_multi.basename('oops') }.to raise_error(ArgumentError)
      end
    end

    context '#changelog' do
      it 'returns the package changelog' do
        expected = <<-EOM
* Wed Jun 10 2015 nobody <nobody@someplace.com> - 1.0.0
- some comment

        EOM
        expect( @sf_info.changelog ).to eq expected
        expect( @sf_info_multi.changelog ).to eq expected

        exp_regex = Regexp.escape('* Wed Jun 10 2015 nobody <nobody@someplace.com> - 1.0.0')
        expect( @sf_info_macros_default.changelog ).to match exp_regex

        expected = IO.read(File.join(@lua_project_dir, 'CHANGELOG')) + "\n"
        expect( @sf_info_lua.changelog ).to eq expected
      end

      it 'returns the package changelog using specified RPM macro values' do
        expected = <<-EOM
* Wed Jun 10 2015 nobody <nobody@someplace.com> - 1.0.0
- The el6 macro has a value of '1'.
- The el7 macro has a value of '%{el7}'.
- The rhel macro has a value of '6'.

        EOM
        expect( @sf_info_macros_set.changelog ).to eq expected
      end

      it 'fails when changelog query fails' do
        sf_info = Simp::Rpm::SpecFileInfo.new(@spec_file )

        failed_result = {
          :exit_status => 1,
          :stdout      => '',
          :stderr      => 'RPM metadata query failed'
        }
        Simp::Utils.expects(:execute).returns(failed_result)
        expect { sf_info.changelog }.to raise_error(/RPM metadata query failed/)
      end
    end

    context '#full_version' do
      it 'returns the package full version' do
        expect( @sf_info.full_version ).to eq '1.0.0-0'
        expect( @sf_info_macros_default.full_version ).to eq "1.0.0-0#{@system_dist_macro}"
        expect( @sf_info_multi.full_version ).to eq '1.0.0-0'
        expect( @sf_info_multi.full_version('testpackage') ).to eq '1.0.0-0'
        expect( @sf_info_multi.full_version('testpackage-doc') ).to eq '1.0.1-2'
        expect( @sf_info_lua.full_version ).to eq '0.0.2-0'
      end

      it 'returns the package full version using specified RPM macro values' do
        expect( @sf_info_macros_set.full_version ).to eq '1.0.0-0.el6'
      end

      it 'fails when invalid package specified' do
        expect { @sf_info.full_version('oops') }.to raise_error(ArgumentError)
        expect { @sf_info_multi.full_version('oops') }.to raise_error(ArgumentError)
      end
    end

    context '#info' do
      it 'returns metadata for the single package found in a simple spec file' do
        info = @sf_info.info
        expect( info.fetch( :basename ) ).to eq 'testpackage'
        expect( info.fetch( :version ) ).to eq '1.0.0'
        expect( info.fetch( :release ) ).to eq '0'
        expect( info.fetch( :full_version ) ).to eq '1.0.0-0'
        expect( info.fetch( :name ) ).to eq 'testpackage-1.0.0-0'
        expect( info.fetch( :arch ) ).to eq 'noarch'
        expect( info.fetch( :rpm_name ) ).to eq 'testpackage-1.0.0-0.noarch.rpm'
      end

      it 'returns the metadata for an individual package found in a multi-package spec file' do
        info = @sf_info_multi.info('testpackage')
        expect( info.fetch( :basename ) ).to eq 'testpackage'
        expect( info.fetch( :version ) ).to eq '1.0.0'
        expect( info.fetch( :release ) ).to eq '0'
        expect( info.fetch( :full_version ) ).to eq '1.0.0-0'
        expect( info.fetch( :name ) ).to eq 'testpackage-1.0.0-0'
        expect( info.fetch( :arch ) ).to eq 'noarch'
        expect( info.fetch( :rpm_name ) ).to eq 'testpackage-1.0.0-0.noarch.rpm'

        info = @sf_info_multi.info('testpackage-doc')
        expect( info.fetch( :basename ) ).to eq 'testpackage-doc'
        expect( info.fetch( :version ) ).to eq '1.0.1'
        expect( info.fetch( :release ) ).to eq '2'
        expect( info.fetch( :full_version ) ).to eq '1.0.1-2'
        expect( info.fetch( :name ) ).to eq 'testpackage-doc-1.0.1-2'
        expect( info.fetch( :arch ) ).to eq 'noarch'
        expect( info.fetch( :rpm_name ) ).to eq 'testpackage-doc-1.0.1-2.noarch.rpm'
      end

      it 'returns metadata for the single package found in a LUA-based spec file' do
        info = @sf_info_lua.info
        expect( info.fetch( :basename ) ).to eq 'pupmod-simp-testpackage_lua'
        expect( info.fetch( :version ) ).to eq '0.0.2'
        expect( info.fetch( :release ) ).to eq '0'
        expect( info.fetch( :full_version ) ).to eq '0.0.2-0'
        expect( info.fetch( :name ) ).to eq 'pupmod-simp-testpackage_lua-0.0.2-0'
        expect( info.fetch( :arch ) ).to eq 'noarch'
        expect( info.fetch( :rpm_name ) ).to eq 'pupmod-simp-testpackage_lua-0.0.2-0.noarch.rpm'
      end
    end

    context '#info_hash' do
      it 'returns metadata for the single package in a simple spec file' do
        expected = {
          'testpackage' => {
            :basename     => 'testpackage',
            :version      => '1.0.0',
            :release      => '0',
            :full_version => '1.0.0-0',
            :name         => 'testpackage-1.0.0-0',
            :arch         => 'noarch',
            :rpm_name     => 'testpackage-1.0.0-0.noarch.rpm'
           }
        }
        expect( @sf_info.info_hash ).to eq expected
      end

      it 'returns metadata for all packages in a multi-package spec file' do
        expected = {
          'testpackage' => {
            :basename     => 'testpackage',
            :version      => '1.0.0',
            :release      => '0',
            :full_version => '1.0.0-0',
            :name         => 'testpackage-1.0.0-0',
            :arch         => 'noarch',
            :rpm_name     => 'testpackage-1.0.0-0.noarch.rpm'
           },
          'testpackage-doc' => {
            :basename     => 'testpackage-doc',
            :version      => '1.0.1',
            :release      => '2',
            :full_version => '1.0.1-2',
            :name         => 'testpackage-doc-1.0.1-2',
            :arch         => 'noarch',
            :rpm_name     => 'testpackage-doc-1.0.1-2.noarch.rpm'
           }
        }
        expect( @sf_info_multi.info_hash ).to eq expected
      end

      it 'returns metadata for the single package found in a LUA-based spec file' do
        expected = {
          'pupmod-simp-testpackage_lua' => {
            :basename     => 'pupmod-simp-testpackage_lua',
            :version      => '0.0.2',
            :release      => '0',
            :full_version => '0.0.2-0',
            :name         => 'pupmod-simp-testpackage_lua-0.0.2-0',
            :arch         => 'noarch',
            :rpm_name     => 'pupmod-simp-testpackage_lua-0.0.2-0.noarch.rpm'
           }
        }
        expect(@sf_info_lua.info_hash ).to eq expected
      end
    end

    context '#name' do
      it 'returns the full package name' do
        expect( @sf_info.name ).to eq 'testpackage-1.0.0-0'
        expect( @sf_info_macros_default.name ).to eq "testpackage-1.0.0-0#{@system_dist_macro}"
        expect( @sf_info_multi.name ).to eq 'testpackage-1.0.0-0'
        expect( @sf_info_multi.name('testpackage') ).to eq 'testpackage-1.0.0-0'
        expect( @sf_info_multi.name('testpackage-doc') ).to eq 'testpackage-doc-1.0.1-2'
        expect( @sf_info_lua.name ).to eq 'pupmod-simp-testpackage_lua-0.0.2-0'
      end

      it 'returns the full package name using specified RPM macro values' do
        expect( @sf_info_macros_set.name ).to eq 'testpackage-1.0.0-0.el6'
      end

      it 'fails when invalid package specified' do
        expect { @sf_info.name('oops') }.to raise_error(ArgumentError)
        expect { @sf_info_multi.name('oops') }.to raise_error(ArgumentError)
      end
    end

    context '#packages' do
      it 'returns the packages specified in the spec file' do
        expect( @sf_info.packages ).to eq ['testpackage']
        expect( @sf_info_macros_default.packages ).to eq ['testpackage']
        expect( @sf_info_multi.packages ).to eq ['testpackage','testpackage-doc']
        expect( @sf_info_lua.packages ).to eq ['pupmod-simp-testpackage_lua']
      end
    end

    context '#release' do
      it 'returns the package release' do
        expect( @sf_info.release ).to eq '0'
        expect( @sf_info_macros_default.release ).to eq "0#{@system_dist_macro}"
        expect( @sf_info_multi.release ).to eq '0'
        expect( @sf_info_multi.release('testpackage') ).to eq '0'
        expect( @sf_info_multi.release('testpackage-doc') ).to eq '2'
        expect( @sf_info_lua.release ).to eq '0'
      end

      it 'returns the package release using specified RPM macro values' do
        expect( @sf_info_macros_set.release ).to eq '0.el6'
      end

      it 'fails when invalid package specified' do
        expect { @sf_info.release('oops') }.to raise_error(ArgumentError)
        expect { @sf_info_multi.release('oops') }.to raise_error(ArgumentError)
      end
    end

    context '#rpm_name' do
      it 'returns the RPM name' do
        expect( @sf_info.rpm_name ).to eq 'testpackage-1.0.0-0.noarch.rpm'
        expect( @sf_info_macros_default.rpm_name ).to eq "testpackage-1.0.0-0#{@system_dist_macro}.noarch.rpm"
        expect( @sf_info_multi.rpm_name ).to eq 'testpackage-1.0.0-0.noarch.rpm'
        expect( @sf_info_multi.rpm_name('testpackage') ).to eq 'testpackage-1.0.0-0.noarch.rpm'
        expect( @sf_info_multi.rpm_name('testpackage-doc') ).to eq 'testpackage-doc-1.0.1-2.noarch.rpm'
        expect( @sf_info_lua.rpm_name ).to eq 'pupmod-simp-testpackage_lua-0.0.2-0.noarch.rpm'
      end

      it 'returns the RPM name using specified RPM macro values' do
        expect( @sf_info_macros_set.rpm_name ).to eq 'testpackage-1.0.0-0.el6.noarch.rpm'
      end

      it 'fails when invalid package specified' do
        expect { @sf_info.rpm_name('oops') }.to raise_error(ArgumentError)
        expect { @sf_info_multi.rpm_name('oops') }.to raise_error(ArgumentError)
      end
    end

    context '#version' do
      it 'returns the RPM version' do
        expect( @sf_info.version ).to eq '1.0.0'
        expect( @sf_info_macros_default.version ).to eq '1.0.0'
        expect( @sf_info_multi.version ).to eq '1.0.0'
        expect( @sf_info_multi.version('testpackage') ).to eq '1.0.0'
        expect( @sf_info_multi.version('testpackage-doc') ).to eq '1.0.1'
        expect( @sf_info_lua.version ).to eq '0.0.2'
      end

      it 'fails when invalid package specified' do
        expect { @sf_info.version('oops') }.to raise_error(ArgumentError)
        expect { @sf_info_multi.version('oops') }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#package_newer?' do

    it 'returns true with other_rpm is nil' do
      expect( @sf_info.package_newer?('testpackage', nil) ).to be true
    end

    it 'returns true with other_rpm is empty' do
      expect( @sf_info.package_newer?('testpackage', '') ).to be true
    end

    it 'returns false when other_rpm has a newer version' do
      expect( @sf_info.package_newer?('testpackage', 'testpackage-1.0.1-0.noarch.rpm') ).to be false
    end

    it 'returns false when other_rpm has the same version and release' do
      expect( @sf_info.package_newer?('testpackage', 'testpackage-1.0.0-0.noarch.rpm') ).to be false
    end

    it 'returns false when other_rpm has the same version but a newer release' do
      expect( @sf_info.package_newer?('testpackage', 'testpackage-1.0.0-2.noarch.rpm') ).to be false
    end

    it 'returns true when other_rpm has an older version' do
      expect( @sf_info.package_newer?('testpackage', 'testpackage-0.1.0-0.noarch.rpm') ).to be true
    end

    it 'returns true when other_rpm has the same version but an older release' do
      expect( @sf_info_multi.package_newer?('testpackage-doc', 'testpackage-doc-1.0.1-1.noarch.rpm') ).to be true
    end

    #FIXME generate an RPM for this comparison
    xit 'makes correct comparison when other_rpm is a readable file'

    it 'fails when other_rpm does not end with .rpm' do
      expect{ @sf_info.package_newer?('testpackage', 'pupmod-simp-beakertest-0.0.1-1') }.to raise_error(ArgumentError)
    end

    it "fails if Gem::Version cannot be constructed from other_rpm's full_version" do
      expect{ @sf_info.package_newer?('testpackage', 'testpackage-x.0.3-0.noarch.rpm') }.
        to raise_error(/could not compare RPMs/)
    end

    it 'fails when invalid package specified' do
      expect { @sf_info.package_newer?('oops', 'testpackage-3.0.0-0.noarch.rpm') }.to raise_error(ArgumentError)
    end
  end

end
