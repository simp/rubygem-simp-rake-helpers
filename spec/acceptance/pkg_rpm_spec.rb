require 'spec_helper_acceptance'

env_vars = {
  :default => '',
  :simp4 => "SIMP_BUILD_version='4.3.1'",
  :simp5 => "SIMP_BUILD_version='5.2.1'"
}

shared_examples_for "a RPM generator" do
  it 'should create an RPM and remove the mock directory when SIMP_RAKE_MOCK_cleanup=yes' do
    on test_host, %(#{run_cmd} "cd #{testpackage_dir}; #{env_vars[build_type]} SIMP_RAKE_MOCK_cleanup=yes rake pkg:rpm[epel-#{test_dist}-x86_64,true]")
    on test_host, %(test -f #{testpackage_rpm})
    on test_host, %(test -d /var/lib/mock/epel-#{test_dist}-x86_64-pupmod-simp-testpackage__$USER), {:acceptable_exit_codes => [1]}
  end

  it 'should use specified release number for the RPM' do
    on test_host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_with_release; #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]")
    release_test_rpm = File.join(pkg_root_dir, 'testpackage_with_release',
      'dist', 'pupmod-simp-testpackage-0.0.1-42.noarch.rpm')
    on test_host, %(test -f #{release_test_rpm})
  end

  it 'should generate a changelog for the RPM when no CHANGELOG exists' do
    on test_host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_without_changelog; #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]")
    changelog_test_rpm = File.join(pkg_root_dir, 'testpackage_without_changelog',
      'dist', File.basename(testpackage_rpm))
    on test_host, %(rpm --changelog -qp #{changelog_test_rpm} | grep -q 'Auto Changelog')
  end

  it 'should not require pupmod-simp-simplib for simp-simplib RPM' do
    on test_host, %(#{run_cmd} "cd #{pkg_root_dir}/simplib; #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]")
    simplib_rpm = File.join(pkg_root_dir, 'simplib', 'dist',
      File.basename(testpackage_rpm).gsub(/simp-testpackage-0.0.1/,'simp-simplib-1.2.3'))
    on test_host, %(test -f #{simplib_rpm})
    on test_host, %(rpm -qpR #{simplib_rpm} | grep -q pupmod-simp-simplib), {:acceptable_exit_codes => [1]}
  end

  it 'should not fail to create an RPM when the CHANGELOG has a bad date' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_with_bad_changelog_date; #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]")

    bad_date_test_rpm = File.join(pkg_root_dir, 'testpackage_with_bad_changelog_date',
      'dist', File.basename(testpackage_rpm))
    on test_host, %(test -f #{bad_date_test_rpm})
  end

  it 'should fail to create an RPM when metadata.json is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_metadata_file; #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when license metadata is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_license; #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when name metadata is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_name; #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]"),
              :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when source metadata is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_source; #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when summary metadata is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_summary; #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when version metadata is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_version; #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]"),
      :acceptable_exit_codes => [1]
  end
end

shared_examples_for "a pre-SIMP6 RPM generator" do
  it "should create an RPM and leave the mock directory when SIMP_RAKE_MOCK_cleanup=no" do
    comment "produces RPM"
    on test_host, %(#{run_cmd} "cd #{testpackage_dir}; SIMP_RAKE_MOCK_cleanup=no #{env_vars[build_type]} rake pkg:rpm[epel-#{test_dist}-x86_64,true]")
    on test_host, %(test -f #{testpackage_rpm})

    comment "produces RPM with appropriate dependencies"
    on test_host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-simp-foo)
    on test_host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-simp-simplib)
    on test_host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-puppetlabs-stdlib)
    on test_host, %(rpm -qp --provides #{testpackage_rpm} | grep -q -x "pupmod-testpackage = 0.0.1-0")
    on test_host, %(rpm -qp --provides #{testpackage_rpm} | grep -q -x "simp-testpackage = 0.0.1-0")
    on test_host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{testpackage_rpm} | grep -q "^pupmod-testpackage")
    on test_host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{testpackage_rpm} | grep -q "^simp-testpackage")

    comment "RPM generated does not require simp-adapter"
    on test_host, %(rpm -qpR #{testpackage_rpm} | grep -q simp-adapter), {:acceptable_exit_codes => [1]}

    comment "produces RPM with a sourced CHANGELOG"
    on test_host, %(rpm --changelog -qp #{testpackage_rpm} | grep -q Stallman)

    comment "produces RPM without SIMP6-specific appropriate pre/post/preun/postun"
    on test_host,
      %(rpm -qp --scripts #{testpackage_rpm} | grep -q -x "/usr/local/sbin/simp_rpm_helper"),
      {:acceptable_exit_codes => [1]}

    comment "keeps mock chroot when SIMP_RAKE_MOCK_cleanup=no"
    on test_host, %(test -d /var/lib/mock/epel-#{test_dist}-x86_64-pupmod-simp-testpackage__build_user)
  end

  it "should handle variants" do
    pending "removed code to pass variant to mock needs to be reinstated for this feature to work"
    fail "INSERT CHECKING CODE HERE"
  end
end

def comment(msg, indent=10)
  logger.optionally_color(Beaker::Logger::MAGENTA, " "*indent + msg)
end


describe 'rake pkg:rpm' do
  before :all do
    # make sure all generated files from previous rake tasks have
    # permissions that allow the copy in the 'prep' below
    root_dir = File.dirname(File.dirname(File.dirname(File.expand_path(__FILE__))))
    dist_dirs = Dir.glob(File.join(root_dir, '**', 'dist'))
    dist_dirs.each { |dir| FileUtils.chmod_R(0755, dir) }
    FileUtils.chmod_R(0755, 'junit')
    FileUtils.chmod_R(0755, 'log')
  end

  let(:run_cmd) { 'runuser build_user -l -c ' }

  let(:testpackages) {
    ['simplib',
     'testpackage',
     'testpackage_missing_license',
     'testpackage_missing_metadata_file',
     'testpackage_missing_name',
     'testpackage_missing_source',
     'testpackage_missing_summary',
     'testpackage_missing_version',
     'testpackage_with_bad_changelog_date',
     'testpackage_with_release',
     'testpackage_without_changelog']
  }

  let(:pkg_root_dir) { '/home/build_user/host_files/spec/acceptance/files' }
  let(:testpackage_dir) { '/home/build_user/host_files/spec/acceptance/files/testpackage' }

  dists = ['6', '7']

  hosts.each do |host|
    context "rpm building on #{host}" do
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

      end

      dists.each do |dist|
        context "for #{dist} distribution using simpdefault.spec" do
          let(:test_host) { host }
          let(:test_dist) { dist }
          let(:build_type) {:default}
          let(:testpackage_rpm) { File.join(testpackage_dir, 'dist/pupmod-simp-testpackage-0.0.1-0.noarch.rpm') }

          it 'should have a clean working environment' do
            testpackages.each do |package|
              on host, %(#{run_cmd} "cd #{pkg_root_dir}/#{package}; rake clean")
            end
          end

          it "should create an RPM for #{dist} and leave the mock directory" do
            comment "produces RPM"
            on test_host, %(#{run_cmd} "cd #{testpackage_dir}; SIMP_RAKE_MOCK_cleanup=no rake pkg:rpm[epel-#{dist}-x86_64,true]")
            on test_host, %(test -f #{testpackage_rpm})

            comment "produces RPM with appropriate dependencies"
            on test_host, %(rpm -qpR #{testpackage_rpm} | grep -q simp-adapter)
            on test_host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-simp-foo)
            on test_host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-simp-simplib)
            on test_host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-puppetlabs-stdlib)
            on test_host, %(rpm -qp --provides #{testpackage_rpm} | grep -q -x "pupmod-testpackage = 0.0.1-0")
            on test_host, %(rpm -qp --provides #{testpackage_rpm} | grep -q -x "simp-testpackage = 0.0.1-0")
            on test_host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{testpackage_rpm} | grep -q "^pupmod-testpackage")
            on test_host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{testpackage_rpm} | grep -q "^simp-testpackage")

            comment "produces RPM with a sourced CHANGELOG"
            on test_host, %(rpm --changelog -qp #{testpackage_rpm} | grep -q Stallman)

            comment "produces RPM with appropriate pre/post/preun/postun"
            on test_host, %(rpm -qp --scripts #{testpackage_rpm} | grep -q -x "/usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='pre' --rpm_status=\\$1")
            on test_host, %(rpm -qp --scripts #{testpackage_rpm} | grep -q -x "/usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='post' --rpm_status=\\$1")
            on test_host, %(rpm -qp --scripts #{testpackage_rpm} | grep -q -x "/usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='preun' --rpm_status=\\$1")
            on test_host, %(rpm -qp --scripts #{testpackage_rpm} | grep -q -x "/usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='postun' --rpm_status=\\$1")

            comment "keeps mock chroot when SIMP_RAKE_MOCK_cleanup=no"
            on test_host, %(test -d /var/lib/mock/epel-#{dist}-x86_64-pupmod-simp-testpackage__build_user)
          end

          it_should_behave_like "a RPM generator"
        end

        context "for #{dist} distribution using simp4.spec" do
          let(:test_host) { host }
          let(:test_dist) { dist }
          let(:build_type) { :simp4 }
          let(:testpackage_rpm) { File.join(testpackage_dir, 'dist/pupmod-simp-testpackage-0.0.1-0.noarch.rpm') }

          it 'should have a clean working environment' do
            testpackages.each do |package|
              on test_host, %(#{run_cmd} "cd #{pkg_root_dir}/#{package}; rake clean")
            end
          end

          it_should_behave_like "a pre-SIMP6 RPM generator"
          it_should_behave_like "a RPM generator"
        end

        context "for #{dist} distribution using simp5.spec" do
          let(:test_host) { host }
          let(:test_dist) { dist }
          let(:build_type) { :simp5 }
          let(:testpackage_rpm) { File.join(testpackage_dir, 'dist/pupmod-simp-testpackage-0.0.1-0.noarch.rpm') }

          it 'should have a clean working environment' do
            testpackages.each do |package|
              on test_host, %(#{run_cmd} "cd #{pkg_root_dir}/#{package}; rake clean")
            end
          end

          it_should_behave_like "a pre-SIMP6 RPM generator"
          it_should_behave_like "a RPM generator"
        end
      end
    end
  end
end
