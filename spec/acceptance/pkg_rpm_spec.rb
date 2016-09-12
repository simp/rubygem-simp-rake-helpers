require 'spec_helper_acceptance'


describe 'rake pkg:rpm' do

  run_cmd = 'runuser build_user -l -c '

  let(:testpackages) { 
    ['simplib',
     'testpackage',
     'testpackage_missing_license',
     'testpackage_missing_metadata_file',
     'testpackage_missing_name',
     'testpackage_missing_source',
     'testpackage_missing_summary',
     'testpackage_missing_version',
     'testpackage_with_release',
     'testpackage_without_changelog']
  }

  let(:pkg_root_dir) { '/home/build_user/host_files/spec/acceptance/files' }
  let(:testpackage_dir) { '/home/build_user/host_files/spec/acceptance/files/testpackage' }
  let(:testpackage_rpm) { File.join(testpackage_dir, 'dist/pupmod-simp-testpackage-0.0.1-1.noarch.rpm') }

  dists = ['6', '7']

  hosts.each do |host|
    context 'with SIMP_RAKE_MOCK_cleanup=no' do
      before :each do
        on host, 'mkdir -p -m 0755 /var/lib/mock'
        on host, 'rm -rf /var/lib/mock/*', :accept_all_exit_codes => true
      end

      context 'prep' do
        it 'should have a local copy of the test directory' do
          on host, %(#{run_cmd} "cp -a /host_files ~")
        end

        it 'should set up the Ruby gems' do
          # all our test packages use the same set of ruby gems, so only bundle
          # update once to save time
          on host, %(#{run_cmd} "cd #{testpackage_dir}; rvm use default; bundle update")
        end

        it 'should have a clean working environment' do
          testpackages.each do |package| 
            on host, %(#{run_cmd} "cd #{pkg_root_dir}/#{package}; rake clean")
          end
        end
      end

      dists.each do |dist|
        context "on #{dist}" do
          it "should create an RPM for #{dist} and leave the mock directory" do

            test_name %(runs SIMP_RAKE_MOCK_cleanup=no pkg:rpm[epel-#{dist}-x86_64,true])
            on host, %(#{run_cmd} "cd #{testpackage_dir}; SIMP_RAKE_MOCK_cleanup=no rake pkg:rpm[epel-#{dist}-x86_64,true]")

            test_name 'produces RPM'
            on host, %(test -f #{testpackage_rpm})

            test_name 'produces RPM with appropriate dependencies'
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q simp-puppetmodule-helper)
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-simp-foo)
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-simp-simplib)
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-puppetlabs-stdlib)
            on host, %(rpm -qp --provides #{testpackage_rpm} | grep -q -x "pupmod-testpackage = 0.0.1-1")
            on host, %(rpm -qp --provides #{testpackage_rpm} | grep -q -x "simp-testpackage = 0.0.1-1")
            on host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{testpackage_rpm} | grep -q "^pupmod-testpackage")
            on host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{testpackage_rpm} | grep -q "^simp-testpackage")

            test_name 'produces RPM with a sourced CHANGELOG'
            on host, %(rpm --changelog -qp #{testpackage_rpm} | grep -q Stallman)

            test_name 'produces RPM with appropriate pre/post/preun/postun'
            on host, %(rpm -qp --scripts #{testpackage_rpm} | grep -q -x '/usr/local/bin/simp_pupmod_update pre $1')
            on host, %(rpm -qp --scripts #{testpackage_rpm} | grep -q -x '/usr/local/bin/simp_pupmod_update post $1')
            on host, %(rpm -qp --scripts #{testpackage_rpm} | grep -q -x '/usr/local/bin/simp_pupmod_update preun $1')
            on host, %(rpm -qp --scripts #{testpackage_rpm} | grep -q -x '/usr/local/bin/simp_pupmod_update postun $1')

            test_name 'keeps mock chroot when SIMP_RAKE_MOCK_cleanup=no'
            on host, %(test -d /var/lib/mock/epel-#{dist}-x86_64-pupmod-simp-testpackage__build_user)
          end

          it 'should create an RPM and remove the mock directory' do
            test_name 'runs pkg:rpm'
            on host, %(#{run_cmd} "cd #{testpackage_dir}; SIMP_RAKE_MOCK_cleanup=yes rake pkg:rpm[epel-#{dist}-x86_64,true]")

            test_name 'produces RPM'
            on host, %(test -f #{testpackage_rpm})

            test_name 'deletes mock chroot when SIMP_RAKE_MOCK_cleanup=yes'
            on host, %(test -d /var/lib/mock/epel-#{dist}-x86_64-pupmod-simp-testpackage__$USER), {:acceptable_exit_codes => [1]}
          end


          it 'should use specified release number for the RPM' do
            test_name 'runs pkg:rpm'
            on host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_with_release; rake pkg:rpm[epel-#{dist}-x86_64,true]")

            test_name 'produces RPM with specified release qualifier'
            release_test_rpm = File.join(pkg_root_dir, 'testpackage_with_release',
              'dist', 'pupmod-simp-testpackage-0.0.1-42.noarch.rpm')
            on host, %(test -f #{release_test_rpm})
          end

          it 'should generate a changelog for the RPM when no CHANGELOG exists' do
            test_name 'runs pkg:rpm'
            on host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_without_changelog; rake pkg:rpm[epel-#{dist}-x86_64,true]")

            test_name 'auto-generates changelog when CHANGELOG is not present'
            changelog_test_rpm = File.join(pkg_root_dir, 'testpackage_without_changelog',
              'dist', 'pupmod-simp-testpackage-0.0.1-1.noarch.rpm')
            on host, %(rpm --changelog -qp #{changelog_test_rpm} | grep -q 'Auto Changelog')
          end

          it 'should not require pupmod-simp-simplib for simp-simplib RPM' do
            test_name 'runs pkg:rpm'
            on host, %(#{run_cmd} "cd #{pkg_root_dir}/simplib; rake pkg:rpm[epel-#{dist}-x86_64,true]")

            test_name 'does not include requires for pupmod-simp-simplib' 
            simplib_rpm = File.join(pkg_root_dir, 'simplib', 'dist', 'pupmod-simp-simplib-1.2.3-1.noarch.rpm')
            on host, %(rpm -qpR #{simplib_rpm} | grep -q pupmod-simp-simplib), {:acceptable_exit_codes => [1]}
          end

          it 'should fail to create an RPM when metadata.json is missing' do
            on host,
               %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_metadata_file; rake pkg:rpm[epel-#{dist}-x86_64,true]"),
              :acceptable_exit_codes => [1]
          end

          it 'should fail to create an RPM when license metadata is missing' do
            on host,
               %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_license; rake pkg:rpm[epel-#{dist}-x86_64,true]"),
              :acceptable_exit_codes => [1]
          end

          it 'should fail to create an RPM when name metadata is missing' do
            on host,
               %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_name; rake pkg:rpm[epel-#{dist}-x86_64,true]"),
              :acceptable_exit_codes => [1]
          end

          it 'should fail to create an RPM when source metadata is missing' do
            on host,
               %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_source; rake pkg:rpm[epel-#{dist}-x86_64,true]"),
              :acceptable_exit_codes => [1]
          end

          it 'should fail to create an RPM when summary metadata is missing' do
            on host,
               %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_summary; rake pkg:rpm[epel-#{dist}-x86_64,true]"),
              :acceptable_exit_codes => [1]
          end

          it 'should fail to create an RPM when version metadata is missing' do
            on host,
               %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_version; rake pkg:rpm[epel-#{dist}-x86_64,true]"),
              :acceptable_exit_codes => [1]
          end

        end
      end

      context 'cleanup' do
        it 'should clean up after itself' do
          on host, %(#{run_cmd} "cd #{testpackage_dir}; rake clean")
        end
      end
    end
  end
end
