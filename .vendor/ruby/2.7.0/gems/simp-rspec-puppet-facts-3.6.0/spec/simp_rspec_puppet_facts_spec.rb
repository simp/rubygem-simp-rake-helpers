require 'spec_helper'

describe 'Simp::RspecPuppetFacts' do


  describe '#on_supported_os' do

    context 'Without parameter' do
      subject { on_supported_os() }

      context 'Without a metadata.json file' do
        it { expect { subject }.to raise_error(StandardError, /Can't find metadata\.json/) }
      end

      context 'With a metadata.json file' do
        before :all do
          Dir.chdir( File.join(File.dirname(__FILE__),'fixtures'))
        end

        it 'should return a hash' do
          expect( on_supported_os().class ).to eq Hash
        end
        it 'should have 4 elements' do
          expect(subject.size).to be >= 4
        end
        it 'should return supported OS' do
          expect(subject.keys.sort).to include 'centos-7-x86_64'
          expect(subject.keys.sort).to include 'centos-8-x86_64'
          expect(subject.keys.sort).to include 'redhat-7-x86_64'
          expect(subject.keys.sort).to include 'redhat-8-x86_64'
        end
        it 'should return SIMP-specific OS facts' do
          grub_version_facts = subject.map{ |os,data|  {os =>
            data.select{ |x,v| x == :uid_min || x == :grub_version }}}
          expect( grub_version_facts ).to include(
            {"centos-8-x86_64"=>{:uid_min=>"1000",  :grub_version=>"2.03"}}
          )
          expect( grub_version_facts ).to include(
            {"centos-7-x86_64"=>{:uid_min=>"1000", :grub_version=>"2.02~beta2"}}
          )
          expect( grub_version_facts ).to include(
            {"redhat-8-x86_64"=>{:uid_min=>"1000",  :grub_version=>"2.03"}}
          )
          expect( grub_version_facts ).to include(
            {"redhat-7-x86_64"=>{:uid_min=>"1000", :grub_version=>"2.02~beta2"}}
          )
        end
      end
    end

    context 'When specifying supported_os=redhat-6-x86_64,redhat-7-x86_64' do
      subject {
        on_supported_os(
          {
            :supported_os => [
              {
                "operatingsystem" => "RedHat",
                "operatingsystemrelease" => [
                  "6",
                  "7"
                ]
              }
            ]
          }
        )
      }
      it 'should return a hash' do
        expect(subject.class).to eq Hash
      end
      it 'should have 2 elements' do
        expect(subject.size).to eq 2
      end
      it 'should return supported OS' do
        expect(subject.keys.sort).to eq [
          'redhat-6-x86_64',
          'redhat-7-x86_64',
        ]
      end
    end

    context 'When specifying SIMP_FACTS_OS=redhat-6-x86_64,redhat-7-x86_64' do
      subject {
        x = ENV['SIMP_FACTS_OS']
        ENV['SIMP_FACTS_OS']='centos,redhat-7-x86_64'
        h = on_supported_os()
        ENV['SIMP_FACTS_OS']=x
        h
      }
      it 'should return a hash' do
        expect(subject.class).to eq Hash
      end
      it 'should have 3 elements' do
        expect(subject.size).to eq 3
      end
      it 'should return supported OS' do
        expect(subject.keys.sort).to eq [
          'centos-7-x86_64',
          'centos-8-x86_64',
          'redhat-7-x86_64',
        ]
      end
    end


    context 'When specifying wrong supported_os' do
      subject {
        on_supported_os(
          {
            :supported_os => [
              {
                "operatingsystem" => "Debian",
                "operatingsystemrelease" => [
                  "X",
                ],
              },
            ]
          }
        )
      }


       it 'should output warning message', skip: "rspec issue: No longer able to catch message on stdout or stderr" do
        expect { subject }.to output(%r(No facts were found in the FacterDB)).to_stdout
      end
    end
  end



  describe '#selinux_facts' do
    context 'When :enforcing' do
      subject { selinux_facts(:enforcing,{}) }
      it 'should return a hash' do
        expect( subject.class ).to eq Hash
      end
      context 'when facts include `:tmp_mount_dev_shm => "rw,noatime"`' do
        subject { selinux_facts(:enforcing,{ :tmp_mount_dev_shm => 'rw,noatime'}) }
        it 'should have a :tmp_mount_dev_shm key' do
          expect( subject.key? :tmp_mount_dev_shm ).to be true
        end
        it ':tmp_mount_dev_shm should include "seclabel"' do
          expect( subject[:tmp_mount_dev_shm] ).to match /\bseclabel\b/
        end
      end
      context 'when facts include `:tmp_mount_dev_shm => "rw,noatime,seclabel"`' do
        subject { selinux_facts(:enforcing,{ :tmp_mount_dev_shm => 'rw,noatime,seclabel'}) }
        it ':tmp_mount_dev_shm should include "seclabel"' do
          expect( subject[:tmp_mount_dev_shm] ).to match /\bseclabel\b/
        end
      end
    end

    context 'When :permissive' do
      subject { selinux_facts(:permissive,{}) }
      it 'should return a hash' do
        expect( subject.class ).to eq Hash
      end
      context 'when facts include `:tmp_mount_dev_shm => "rw,noatime"`' do
        subject { selinux_facts(:permissive,{ :tmp_mount_dev_shm => 'rw,noatime'}) }
        it 'should have a :tmp_mount_dev_shm key' do
          expect( subject.key? :tmp_mount_dev_shm ).to be true
        end
        it ':tmp_mount_dev_shm should include "seclabel"' do
          expect( subject[:tmp_mount_dev_shm] ).to match /\bseclabel\b/
        end
      end
      context 'when facts include `:tmp_mount_dev_shm => "rw,noatime,seclabel"`' do
        subject { selinux_facts(:permissive,{ :tmp_mount_dev_shm => 'rw,noatime,seclabel'}) }
        it ':tmp_mount_dev_shm should include "seclabel"' do
          expect( subject[:tmp_mount_dev_shm] ).to match /\bseclabel\b/
        end
      end
    end

    context 'When :disabled' do
      subject { selinux_facts(:disabled,{}) }
      it 'should return a hash' do
        expect( subject.class ).to eq Hash
      end
      context 'when facts include `:tmp_mount_dev_shm => "rw,noatime"`' do
        subject { selinux_facts(:disabled,{ :tmp_mount_dev_shm => 'rw,noatime'}) }
        it 'should have a :tmp_mount_dev_shm key' do
          expect( subject.key? :tmp_mount_dev_shm ).to be true
        end
        it ':tmp_mount_dev_shm should not include "seclabel"' do
          expect( subject[:tmp_mount_dev_shm] ).to_not match /\bseclabel\b/
        end
      end
      context 'when facts include `:tmp_mount_dev_shm => "rw,noatime,seclabel"`' do
        subject { selinux_facts(:disabled,{ :tmp_mount_dev_shm => 'rw,noatime,seclabel'}) }
        it ':tmp_mount_dev_shm should not include "seclabel"' do
          expect( subject[:tmp_mount_dev_shm] ).to_not match /\bseclabel\b/
        end
      end
    end

  end
end
