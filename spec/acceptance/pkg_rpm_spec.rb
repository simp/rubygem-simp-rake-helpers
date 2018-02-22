require 'spec_helper_acceptance'

def comment(msg, indent=10)
  logger.optionally_color(Beaker::Logger::MAGENTA, " "*indent + msg)
end

def run_cmd
  'runuser build_user -l -c '
end

def pkg_root_dir
  '/home/build_user/host_files/spec/acceptance/files'
end

def packages_to_clean
  [
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
   'testpackage_custom_scriptlet',
  ]
end

def scriptlet_ids
  # key   = `rpm -q --scripts` title
  # value = `simp_rpm_helper` mapping
  {
     'pretrans'      => nil,
     'preinstall'    => 'pre',
     'postinstall'   => 'post',
     'preuninstall'  => 'preun',
     'postuninstall' => 'postun',
     'posttrans'     => nil,
  }
end


# find and return a scriptlet without title, comments, or bordering whitespace
#
#   rpm_label  = label of scriptlet, as reported by `rpm -q --scripts`
#   scriptlets = array of scriptlets
#
def strip_scriptlet( rpm_label, scriptlets )
  _ = scriptlets.grep(/\A#{rpm_label} scriptlet(\b.*)?$/).join("\n")
  _.gsub(/\A#{rpm_label} scriptlet(\b.*)?$|^#.*$/,'').strip
end



shared_examples_for "a customizable RPM generator" do
  context 'when valid custom data is defined under rpm_metadata' do
    it 'should create an RPM' do
      on host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_custom_scriptlet; )+
                 %(SIMP_RAKE_PKG_LUA_verbose=yes SIMP_RPM_LUA_debug=yes SIMP_RAKE_PKG_verbose=yes SIMP_RPM_verbose=yes rake pkg:rpm")
    end

    it 'should create an RPM with customized scriptlets' do
      rx_scriptlet_names  = scriptlet_ids.keys.join('|')
      rx_scriptlet_blocks = /^(?<block>(?<scriptlet>#{rx_scriptlet_names}) scriptlet.*?)(?=\n#{rx_scriptlet_names}|\Z)/m


      result     = on host, %(rpm -qp --scripts #{pkg_root_dir}/testpackage_custom_scriptlet/dist/pupmod-simp-testpackage-0.0.1-0.noarch.rpm)
      scriptlets = []
      result.stdout.scan(rx_scriptlet_blocks) do
        scriptlets << $~[:block]
      end

      comment '...pretrans scriptlet contains custom content'
      content = strip_scriptlet( 'pretrans', scriptlets )
      expect(content).to eq '-- Custom scriptlet'

      comment '...preinstall scriptlet has been overridden with custom content'
      content = strip_scriptlet( 'preinstall', scriptlets )
      expect(content).to eq "echo 'I override the default %%pre section provided by the spec file.'"


      comment '...remaining default scriptlets call simp_rpm_helper with correct arguments'
      expected_simp_scriptlets = scriptlet_ids.select{|k,v| %w(post preun postun).include? v }
      expected_simp_scriptlets.each do |rpm_label, simp_label|
        content = strip_scriptlet( rpm_label, scriptlets )
        expect(content).to eq "/usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='#{simp_label}' --rpm_status=$1"
      end
    end

    it 'should create an RPM with customized triggers' do
###   triggerun scriptlet (using /bin/sh) -- bar
###   # Custom trigger
###   echo "This trigger runs just before the 'bar' package's %%preun"
###   triggerun scriptlet (using /bin/sh) -- foo
###   # Custom trigger
###   echo "The 'foo' package is great; why would you uninstall it?"
      rx_trigger_line = 'trigger.+ scriptlet \(using [/a-z]+\) .*'
      r=/^(trigger\w+ scriptlet \(using [\/a-z]+\) --[- a-z_0-9.\/]*\n.*?)(?=\ntrig|\Z)/m

      result   = on host, %(rpm -qp --triggers #{pkg_root_dir}/testpackage_custom_scriptlet/dist/pupmod-simp-testpackage-0.0.1-0.noarch.rpm)
      triggers = []

      require 'pry'; binding.pry
    end
  end
end

shared_examples_for "an RPM generator with edge cases" do
  it 'should use specified release number for the RPM' do
    on host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_with_release; rake pkg:rpm")
    release_test_rpm = File.join(pkg_root_dir, 'testpackage_with_release',
      'dist', 'pupmod-simp-testpackage-0.0.1-42.noarch.rpm')
    on host, %(test -f #{release_test_rpm})
  end

  it 'should generate a changelog for the RPM when no CHANGELOG exists' do
    on host, %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_without_changelog; rake pkg:rpm")
    changelog_test_rpm = File.join(pkg_root_dir, 'testpackage_without_changelog',
      'dist', File.basename(testpackage_rpm))
    on host, %(rpm --changelog -qp #{changelog_test_rpm} | grep -q 'Auto Changelog')
  end

  it 'should not require pupmod-simp-simplib for simp-simplib RPM' do
    on host, %(#{run_cmd} "cd #{pkg_root_dir}/simplib; rake pkg:rpm")
    simplib_rpm = File.join(pkg_root_dir, 'simplib', 'dist',
      File.basename(testpackage_rpm).gsub(/simp-testpackage-0.0.1/,'simp-simplib-1.2.3'))
    on host, %(test -f #{simplib_rpm})
    on host, %(rpm -qpR #{simplib_rpm} | grep -q pupmod-simp-simplib), {:acceptable_exit_codes => [1]}
  end

  it 'should not fail to create an RPM when the CHANGELOG has a bad date' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_with_bad_changelog_date; rake pkg:rpm")

    bad_date_test_rpm = File.join(pkg_root_dir, 'testpackage_with_bad_changelog_date',
      'dist', File.basename(testpackage_rpm))
    on host, %(test -f #{bad_date_test_rpm})
  end

  it 'should fail to create an RPM when metadata.json is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_metadata_file; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when license metadata is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_license; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when name metadata is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_name; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when source metadata is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_source; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when summary metadata is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_summary; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

  it 'should fail to create an RPM when version metadata is missing' do
    on host,
      %(#{run_cmd} "cd #{pkg_root_dir}/testpackage_missing_version; rake pkg:rpm"),
      :acceptable_exit_codes => [1]
  end

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


    hosts.each do |host|
      on host, 'cp -a /host_files /home/build_user/; chown -R build_user:build_user /home/build_user/host_files'
      packages_to_clean.each do |package|
        on host, %Q(#{run_cmd} "cd #{pkg_root_dir}/#{package}; ) +
                  %Q(rvm use default; bundle update --local || bundle update")
      end
    end
  end


  hosts.each do |_host|
    context "on #{_host}" do
      let!(:host){ _host }

      context 'rpm building' do
        let(:testpackage_dir) { '/home/build_user/host_files/spec/acceptance/files/testpackage' }

        context 'using simpdefault.spec' do

          let(:build_type) {:default}
          let(:testpackage_rpm) { File.join(testpackage_dir, 'dist/pupmod-simp-testpackage-0.0.1-0.noarch.rpm') }

          it_should_behave_like "a customizable RPM generator"

          it 'should create an RPM' do
            comment "produces RPM on #{host}"
            on host, %(#{run_cmd} "cd #{testpackage_dir}; SIMP_RAKE_PKG_LUA_verbose=yes SIMP_RPM_LUA_debug=yes SIMP_RAKE_PKG_verbose=yes SIMP_RPM_verbose=yes rake pkg:rpm")
            on host, %(test -f #{testpackage_rpm})

            comment 'produces RPM with appropriate dependencies'
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q simp-adapter)
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-simp-foo)
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-simp-simplib)
            on host, %(rpm -qpR #{testpackage_rpm} | grep -q pupmod-puppetlabs-stdlib)
            on host, %(rpm -qp --provides #{testpackage_rpm} | grep -q -x 'pupmod-testpackage = 0.0.1-0')
            on host, %(rpm -qp --provides #{testpackage_rpm} | grep -q -x 'simp-testpackage = 0.0.1-0')
            on host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{testpackage_rpm} | grep -q "^pupmod-testpackage")
            on host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{testpackage_rpm} | grep -q "^simp-testpackage")

            comment 'produces RPM with a sourced CHANGELOG'
            on host, %(rpm --changelog -qp #{testpackage_rpm} | grep -q Stallman)

            comment 'produces RPM with appropriate pre/post/preun/postun'
            result = on host, %(rpm -qp --scripts #{testpackage_rpm})
            scriptlets = result.stdout.scan( %r{^.*?scriptlet.*?/usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage.*?$}m )

            expect( scriptlets.grep( %r{\Apreinstall scriptlet.*\n/usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='pre' --rpm_status=\$1\Z}m )).not_to be_empty
            expect( scriptlets.grep( %r{\Apostinstall scriptlet.*\n/usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='post' --rpm_status=\$1\Z}m )).not_to be_empty
            expect( scriptlets.grep( %r{\Apreuninstall scriptlet.*\n/usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='preun' --rpm_status=\$1\Z}m )).not_to be_empty
            expect( scriptlets.grep( %r{\Apostuninstall scriptlet.*\n/usr/local/sbin/simp_rpm_helper --rpm_dir=/usr/share/simp/modules/testpackage --rpm_section='postun' --rpm_status=\$1\Z}m )).not_to be_empty
          end

          it_should_behave_like 'an RPM generator with edge cases'
        end
      end
    end
  end
end
