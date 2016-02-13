require 'spec_helper_acceptance'


describe 'rake pkg:rpm[epel-6-x86_64,true]' do
  before :all do
    on 'container', 'bash --login -c "cd /host_files/spec/acceptance/files/testpackage; \
                     gem install bundler; \
                     bundle"'
  end

  context 'with SIMP_RAKE_MOCK_cleanup=no' do
    before :each do
      on 'container', 'mkdir -p -m 0755 /var/lib/mock'
      on 'container', 'rm -rf /var/lib/mock/* /host_files/spec/acceptance/files/testpackage/dist',
                      :accept_all_exit_codes => true
    end

    it 'should create an RPM and leave the mock directory' do

      test_name 'runs SIMP_RAKE_MOCK_cleanup=no pkg:rpm[epel-6-x86_64,true]'
      on 'container', 'SIMP_RAKE_MOCK_cleanup=no bash --login -c "cd /host_files/spec/acceptance/files/testpackage;  bundle exec rake pkg:rpm[epel-6-x86_64,true]"'

      test_name 'produces RPM'
      on 'container', 'test -f /host_files/spec/acceptance/files/testpackage/dist/testpackage-1-0.noarch.rpm'

      test_name 'keeps mock chroot when SIMP_RAKE_MOCK_cleanup=no'
      on 'container', 'test -d /var/lib/mock/epel-6-x86_64-testpackage__$USER'
    end

    it 'should create an RPM and leave the mock directory' do

      test_name 'runs pkg:rpm'
      on 'container', 'SIMP_RAKE_MOCK_cleanup=yes bash --login -c "cd /host_files/spec/acceptance/files/testpackage;  bundle exec rake pkg:rpm[epel-6-x86_64,true]"'

      test_name 'produces RPM'
      on 'container', 'test -f /host_files/spec/acceptance/files/testpackage/dist/testpackage-1-0.noarch.rpm'

      test_name 'deletes mock chroot when SIMP_RAKE_MOCK_cleanup=yes'
      on 'container', 'test -d /var/lib/mock/epel-6-x86_64-testpackage__$USER', {:acceptable_exit_codes => [1]}
    end
  end
end
