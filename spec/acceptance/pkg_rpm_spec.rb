require 'spec_helper_acceptance'


shared_examples_for "a RPM generator" do
  it 'should use specified release number for the RPM' do
    on test_host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_with_release; rake pkg:rpm")
    release_test_rpm = File.join(pkg_root_dir, 'testpackage_with_release',
      'dist', 'pupmod-simp-testpackage-0.0.1-42.noarch.rpm')
    on test_host, %(test -f #{release_test_rpm})
  end

  it 'should generate a changelog for the RPM when no CHANGELOG exists' do
    on test_host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_without_changelog; rake pkg:rpm")
    changelog_test_rpm = File.join(pkg_root_dir, 'testpackage_without_changelog',
      'dist', File.basename(testpackage_rpm))
    on test_host, %(rpm --changelog -qp #{changelog_test_rpm} | grep -q 'Auto Changelog')
  end

  it 'should not require pupmod-simp-simplib for simp-simplib RPM' do
    on test_host, %(#{run_cmd} "cd #{pkg_root_dir}/simplib; rake pkg:rpm")
    simplib_rpm = File.join(pkg_root_dir, 'simplib', 'dist',
      File.basename(testpackage_rpm).gsub(/simp-testpackage-0.0.1/,'simp-simplib-1.2.3'))
    on test_host, %(test -f #{simplib_rpm})
    on test_host, %(rpm -qpR #{simplib_rpm} | grep -q pupmod-simp-simplib), {:acceptable_exit_codes => [1]}
  end

  it 'should not fail to create an RPM when the CHANGELOG has a bad date' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_with_bad_changelog_date; rake pkg:rpm")

    bad_date_test_rpm = File.join(pkg_root_dir, 'testpackage_with_bad_changelog_date',
      'dist', File.basename(testpackage_rpm))
    on test_host, %(test -f #{bad_date_test_rpm})
  end

  it 'should fail to create an RPM when metadata.json is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_metadata_file; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when license metadata is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_license; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when name metadata is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_name; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when source metadata is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_source; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when summary metadata is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_summary; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when version metadata is missing' do
    on test_host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_version; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
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

  hosts.each do |host|
    context "rpm building on #{host}" do

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

      context "using simpdefault.spec" do
        let(:test_host) { host }
        let(:build_type) {:default}
        let(:testpackage_rpm) { File.join(testpackage_dir, 'dist/pupmod-simp-testpackage-0.0.1-0.noarch.rpm') }

        it 'should have a clean working environment' do
          testpackages.each do |package|
            on host, %(#{run_cmd} "cd #{pkg_root_dir}/#{package}; rake clean")
          end
        end

        it "should create an RPM" do
          comment "produces RPM"
          on test_host, %(#{run_cmd} "cd #{testpackage_dir}; rake pkg:rpm")
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
        end

        it_should_behave_like "a RPM generator"
      end
    end
  end
end
