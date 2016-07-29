require 'spec_helper_acceptance'


describe 'rake pkg:rpm' do

  run_cmd = 'runuser build_user -l -c '

  let(:pkg_input_dir) { '/host_files/spec/acceptance/files/testpackage' }
  let(:pkg_output_dir) { '/home/build_user/host_files/spec/acceptance/files/testpackage' }
  let(:pkg_dest) { File.join(pkg_output_dir, 'dist/pupmod-simp-testpackage-0.0.1-2016.noarch.rpm') }

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
          on host, %(#{run_cmd} "cd #{pkg_output_dir}; rvm use default; bundle update")
        end

        it 'should have a clean working environment' do
          on host, %(#{run_cmd} "cd #{pkg_output_dir}; rake clean")
        end
      end

      dists.each do |dist|
        context "on #{dist}" do
          it "should create an RPM for #{dist} and leave the mock directory" do

            test_name %(runs SIMP_RAKE_MOCK_cleanup=no pkg:rpm[epel-#{dist}-x86_64,true])
            on host, %(#{run_cmd} "cd #{pkg_output_dir}; SIMP_RAKE_MOCK_cleanup=no rake pkg:rpm[epel-#{dist}-x86_64,true]")

            test_name 'produces RPM'
            on host, %(test -f #{pkg_dest})

            test_name 'produces RPM with appropriate dependencies'
            on host, %(rpm -qpR #{pkg_dest} | grep -q pupmod-simp-foo)
            on host, %(rpm -qpR #{pkg_dest} | grep -q pupmod-simp-simplib)
            on host, %(rpm -qpR #{pkg_dest} | grep -q pupmod-puppetlabs-stdlib)
            on host, %(rpm -qp --provides #{pkg_dest} | grep -q "^pupmod-testpackage = 0.0.1-2016$")
            on host, %(rpm -qp --provides #{pkg_dest} | grep -q "^simp-testpackage = 0.0.1-2016$")
            on host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{pkg_dest} | grep -q "^pupmod-testpackage")
            on host, %(rpm -qp --queryformat "[%{obsoletes}\\n]" #{pkg_dest} | grep -q "^simp-testpackage")

            test_name 'produces RPM with a sourced CHANGELOG'
            on host, %(rpm --changelog -qp #{pkg_dest} | grep -q Stallman)

            test_name 'keeps mock chroot when SIMP_RAKE_MOCK_cleanup=no'
            on host, %(test -d /var/lib/mock/epel-#{dist}-x86_64-pupmod-simp-testpackage__build_user)
          end

          it 'should create an RPM and remove the mock directory' do
            test_name 'runs pkg:rpm'
            on host, %(#{run_cmd} "cd #{pkg_output_dir}; SIMP_RAKE_MOCK_cleanup=yes rake pkg:rpm[epel-#{dist}-x86_64,true]")

            test_name 'produces RPM'
            on host, %(test -f #{pkg_dest})

            test_name 'deletes mock chroot when SIMP_RAKE_MOCK_cleanup=yes'
            on host, %(test -d /var/lib/mock/epel-#{dist}-x86_64-pupmod-simp-testpackage__$USER), {:acceptable_exit_codes => [1]}
          end
        end
      end

      context 'cleanup' do
        it 'should clean up after itself' do
          on host, %(#{run_cmd} "cd #{pkg_output_dir}; rake clean")
        end
      end
    end
  end
end
