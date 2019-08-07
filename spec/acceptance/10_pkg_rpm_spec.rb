require 'spec_helper_acceptance'
require_relative 'support/pkg_rpm_helpers'

RSpec.configure do |c|
  c.include Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
end

shared_examples_for "an RPM generator with edge cases" do
  it 'should use specified release number for the RPM' do
    on host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_with_release; #{rake_cmd} pkg:rpm")
    release_test_rpm = File.join(pkg_root_dir, 'testpackage_with_release',
      'dist', 'pupmod-simp-testpackage-0.0.1-42.noarch.rpm')
    on host, %(test -f #{release_test_rpm})
  end

  it 'should generate a changelog for the RPM when no CHANGELOG exists' do
    on host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_without_changelog; #{rake_cmd} pkg:rpm")
    changelog_test_rpm = File.join(pkg_root_dir, 'testpackage_without_changelog',
      'dist', File.basename(testpackage_rpm))
    on host, %(rpm --changelog -qp #{changelog_test_rpm} | grep -q 'Auto Changelog')
  end

  it 'should not require pupmod-simp-simplib for simp-simplib RPM' do
    on host, %(#{run_cmd} "cd #{pkg_root_dir}/simplib; #{rake_cmd} pkg:rpm")
    simplib_rpm = File.join(pkg_root_dir, 'simplib', 'dist',
      File.basename(testpackage_rpm).gsub(/simp-testpackage-0.0.1/,'simp-simplib-1.2.3'))
    on host, %(test -f #{simplib_rpm})
    on host, %(rpm -qpR #{simplib_rpm} | grep -q pupmod-simp-simplib), {:acceptable_exit_codes => [1]}
  end

  it 'should not fail to create an RPM when the CHANGELOG has a bad date' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_with_bad_changelog_date; #{rake_cmd} pkg:rpm")

    bad_date_test_rpm = File.join(pkg_root_dir, 'testpackage_with_bad_changelog_date',
      'dist', File.basename(testpackage_rpm))
    on host, %(test -f #{bad_date_test_rpm})
  end

  it 'should fail to create an RPM when metadata.json is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_metadata_file; #{rake_cmd} pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when license metadata is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_license; #{rake_cmd} pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when name metadata is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_name; #{rake_cmd} pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when source metadata is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_source; #{rake_cmd} pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when summary metadata is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_summary; #{rake_cmd} pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when version metadata is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_version; #{rake_cmd} pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

end

describe 'rake pkg:rpm' do
  before :all do
    copy_host_files_into_build_user_homedir(hosts)
  end


  hosts.each do |_host|
    context "on #{_host}" do
      let!(:host){ _host }

      context 'rpm building' do

        let(:pkg_root_dir){'/home/build_user/host_files/spec/acceptance/files'}
        let(:testpackage_dir){"#{pkg_root_dir}/testpackage"}

        it 'can prep the package directories' do
          testpackages = [
           'simplib',
           'testpackage',
           'testpackage_missing_license',
           'testpackage_missing_metadata_file',
           'testpackage_missing_name',
           'testpackage_missing_source',
           'testpackage_missing_summary',
           'testpackage_missing_version',
           'testpackage_with_bad_changelog_date',
           'testpackage_with_release',
           'testpackage_without_changelog',
          ]

          testpackages.each do |package|
            on hosts, %Q(#{run_cmd} "cd #{pkg_root_dir}/#{package}; ) +
                      %Q(rvm use default; bundle update --local || bundle update")
          end
        end

        context 'using simpdefault.spec' do

          let(:build_type) {:default}
          let(:testpackage_rpm) { File.join(testpackage_dir, 'dist/pupmod-simp-testpackage-0.0.1-0.noarch.rpm') }

          it 'should create an RPM' do
            comment "produces RPM on #{host}"
            on host, %(#{run_cmd} "cd #{testpackage_dir}; #{rake_cmd} pkg:rpm")
            on host, %(test -f #{testpackage_rpm})

            comment 'produces RPM with appropriate dependencies'
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q simp-adapter)
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-simp-foo), :acceptable_exit_codes => [1]
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-simp-simplib)
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-puppetlabs-stdlib)
            on host, %(rpm -qp --provides #{testpackage_rpm} | grep -q -x 'pupmod-testpackage = 0.0.1-0')
            on host, %(rpm -qp --provides #{testpackage_rpm} | grep -q -x 'simp-testpackage = 0.0.1-0')
            on host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{testpackage_rpm} | grep -q "^pupmod-testpackage")
            on host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{testpackage_rpm} | grep -q "^simp-testpackage")

            comment 'produces RPM with a sourced CHANGELOG'
            on host, %(rpm --changelog -qp #{testpackage_rpm} | grep -q Stallman)

            comment 'produces RPM with appropriate pre/preun/postun/posttrans'
            scriptlets = rpm_scriptlets_for(host, testpackage_rpm)

            comment '...the expected scriptlet types are present'
            expect(scriptlets.keys.sort).to eq [
              'preinstall',
              'preuninstall',
              'postuninstall',
              'posttrans',
            ].sort

            comment '...default preinstall scriptlet'
            expected =<<-EOM
# (default scriptlet for SIMP 6.x)
# when $1 = 1, this is an install
# when $1 = 2, this is an upgrade
mkdir -p /var/lib/rpm-state/simp-adapter
touch /var/lib/rpm-state/simp-adapter/rpm_status$1.testpackage
if [ -x /usr/local/sbin/simp_rpm_helper ] ; then
  /usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='pre' --rpm_status=$1
fi
            EOM
            expect(scriptlets['preinstall'][:content]).to eq( expected.strip )

            comment '...default preuninstall scriptlet'
            expected =<<-EOM
# (default scriptlet for SIMP 6.x)
# when $1 = 1, this is the uninstall of the previous version during an upgrade
# when $1 = 0, this is the uninstall of the only version during an erase
if [ -x /usr/local/sbin/simp_rpm_helper ] ; then
  /usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='preun' --rpm_status=$1
fi
            EOM
            expect(scriptlets['preuninstall'][:content]).to eq( expected.strip )

            comment '...default postuninstall scriptlet'
            expected =<<-EOM
# (default scriptlet for SIMP 6.x)
# when $1 = 1, this is the uninstall of the previous version during an upgrade
# when $1 = 0, this is the uninstall of the only version during an erase
if [ -x /usr/local/sbin/simp_rpm_helper ] ; then
  /usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='postun' --rpm_status=$1
fi
            EOM
            expect(scriptlets['postuninstall'][:content]).to eq( expected.strip )

            comment '...default posttrans scriptlet'
            expected =<<-EOM
# (default scriptlet for SIMP 6.x)
# Marker file is created in %pre and only exists for installs or upgrades
# when marker file is prepended with 'rpm_status1.', this is an install
# when marker file is prepended with 'rpm_status2.', this is an upgrade
if [ -e /var/lib/rpm-state/simp-adapter/rpm_status1.testpackage ] ; then
  rm /var/lib/rpm-state/simp-adapter/rpm_status1.testpackage
  if [ -x /usr/local/sbin/simp_rpm_helper ] ; then
    /usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='posttrans' --rpm_status=1
  fi
elif [ -e /var/lib/rpm-state/simp-adapter/rpm_status2.testpackage ] ; then
  rm /var/lib/rpm-state/simp-adapter/rpm_status2.testpackage
  if [ -x /usr/local/sbin/simp_rpm_helper ] ; then
    /usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='posttrans' --rpm_status=2
  fi
fi
            EOM
            expect(scriptlets['posttrans'][:content]).to eq( expected.strip )
          end

          it_should_behave_like 'an RPM generator with edge cases'
        end
      end
    end
  end
end
