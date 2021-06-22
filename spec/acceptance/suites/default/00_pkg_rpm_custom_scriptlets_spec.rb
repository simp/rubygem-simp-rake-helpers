require 'spec_helper_acceptance'
require_relative 'support/pkg_rpm_helpers'

RSpec.configure do |c|
  c.include Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
  c.extend  Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers
end

shared_examples_for 'an RPM generator with customized scriptlets' do
  it 'should create an RPM with customized scriptlets' do
    scriptlets = rpm_scriptlets_for(
      host,
      "#{pkg_root_dir}/testpackage_custom_scriptlet/dist/" +
      'pupmod-simp-testpackage-0.0.1-0.noarch.rpm'
    )

    comment '...the expected scriptlet types are present'
    expect(scriptlets.keys.sort).to eq [
      'pretrans',
      'preinstall',
      'posttrans',
      'preuninstall',
      'postuninstall',
    ].sort

    comment '...there are no duplicates' # this *should* be impossible
    expect(scriptlets.map{|k,v| v[:count]}.max).to be == 1

    comment '...pretrans scriptlet contains custom content'
    expect(scriptlets['pretrans'][:content]).to eq '-- Custom scriptlet'

    comment '...preinstall scriptlet has been overridden with custom content'
    expect(scriptlets['preinstall'][:bare_content]).to eq(
      "echo 'I override the default %%pre section provided by the spec file.'"
    )

    comment '...default preun postun scriptlets call simp_rpm_helper with correct arguments'
    expected_simp_rpm_helper_scriptlets = scriptlet_label_map.select{|k,v| %w(preun postun).include? v }
    expected_simp_rpm_helper_scriptlets.each do |rpm_label, simp_helper_label|
      expected = <<~EOM
        if [ -x /usr/local/sbin/simp_rpm_helper ] ; then
          /usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='#{simp_helper_label}' --rpm_status=$1
        fi
      EOM
      expect(scriptlets[rpm_label][:bare_content]).to eq(expected.strip)
    end

    comment '...default posttrans scriptlet calls simp_rpm_helper with correct arguments'
    expected = <<~EOM
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
    expect(scriptlets['posttrans'][:bare_content]).to eq(expected.strip)
  end
end

shared_examples_for 'an RPM generator with customized triggers' do

  it 'should create an RPM with customized triggers' do
    triggers = rpm_triggers_for(
      host,
      "#{pkg_root_dir}/testpackage_custom_scriptlet/dist/" +
      'pupmod-simp-testpackage-0.0.1-0.noarch.rpm'
    )


    comment '...the expected trigger types are present'
    expect(triggers.keys.sort).to eq [
      'triggerun scriptlet (using /bin/sh) -- bar',
      'triggerun scriptlet (using /bin/sh) -- foo',
    ]

    comment '...there are no duplicates' # <-- this also should be impossible
    expect(triggers.map{|k,v| v[:count]}.max).to be == 1

    comment '..."triggerun -- foo" contains the expected content'
    expect(triggers['triggerun scriptlet (using /bin/sh) -- foo'][:bare_content]).to eq(
      %q{echo "The 'foo' package is great; why would you uninstall it?"}
    )

    comment '..."triggerun -- bar" contains the expected content'
    expect(triggers['triggerun scriptlet (using /bin/sh) -- bar'][:bare_content]).to eq(
      %q{echo "This trigger runs just before the 'bar' package's %%preun"}
    )
  end

end

describe 'rake pkg:rpm with customized content' do

  before :all do
    copy_host_files_into_build_user_homedir(hosts)
  end

  let(:pkg_root_dir){'/home/build_user/host_files/spec/acceptance/files'}
  let(:testpackage_dir){"#{pkg_root_dir}/testpackage"}

  hosts.each do |_host|
    context "on #{_host}" do
      let!(:host){ _host }

      it 'can prep the package directories' do
        testpackages = [
         'testpackage_custom_scriptlet',
        ]

        testpackages.each do |package|
          on hosts, %Q(#{run_cmd} "cd #{pkg_root_dir}/#{package}; ) +
                    %Q(rvm use default; bundle update --local || bundle update")
        end
      end

      context 'when valid custom content is defined under rpm_metadata' do

        it 'should create an RPM' do
          on host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_custom_scriptlet; #{rake_cmd} pkg:rpm")
        end

        it_should_behave_like 'an RPM generator with customized scriptlets'
        it_should_behave_like 'an RPM generator with customized triggers'

      end
    end
  end
end
