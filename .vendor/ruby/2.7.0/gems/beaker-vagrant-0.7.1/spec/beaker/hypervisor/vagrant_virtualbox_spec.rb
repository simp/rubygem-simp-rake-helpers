require 'spec_helper'

describe Beaker::VagrantVirtualbox do
  let( :options ) { make_opts.merge({ :hosts_file => 'sample.cfg', 'logger' => double().as_null_object }) }
  let( :vagrant ) { described_class.new( hosts, options ) }
  let(:vagrantfile_path) { vagrant.instance_variable_get( :@vagrant_file ) }
  let(:hosts) { make_hosts() }

  it "uses the virtualbox provider for provisioning" do
    hosts.each do |host|
      host_prev_name = host['user']
      expect( vagrant ).to receive( :set_ssh_config ).with( host, 'vagrant' ).once
      expect( vagrant ).to receive( :copy_ssh_to_root ).with( host, options ).once
      expect( vagrant ).to receive( :set_ssh_config ).with( host, host_prev_name ).once
    end
    expect( vagrant ).to receive( :hack_etc_hosts ).with( hosts, options ).once
    expect( vagrant ).to receive( :vagrant_cmd ).with( "up --provider virtualbox" ).once
    vagrant.provision
  end

  context 'can make a Vagrantfile' do
    subject do
      FakeFS do
        vagrant.make_vfile(hosts)
        File.read(vagrant.instance_variable_get(:@vagrant_file))
      end
    end

    it "can make a Vagrantfile for a set of hosts" do
      is_expected.to include( %Q{    v.vm.provider :virtualbox do |vb|\n      vb.customize ['modifyvm', :id, '--memory', '1024', '--cpus', '1', '--audio', 'none']\n    end})
    end

    context 'with ioapic(multiple cores)' do
      let(:hosts) { make_hosts({:ioapic => 'true'}, 1) }

      it { is_expected.to include( " vb.customize ['modifyvm', :id, '--ioapic', 'on']") }
    end

    context 'with NAT DNS' do
      let(:hosts) { make_hosts({:natdns => 'on'}, 1) }

      it { is_expected.to include( " vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']") }
      it { is_expected.to include( " vb.customize ['modifyvm', :id, '--natdnsproxy1', 'on']") }
    end

    context 'storage with the USB controller' do
      let(:hosts) { make_hosts({:volumes => { 'test_disk' => { size: '5120' }}, :volume_storage_controller => 'USB' }) }

      it { is_expected.to include(" vb.customize ['modifyvm', :id, '--usb', 'on']") }
      it { is_expected.to include(" vb.customize ['storagectl', :id, '--name', 'Beaker USB Controller', '--add', 'usb', '--portcount', '8', '--controller', 'USB', '--bootable', 'off']") }
      it { is_expected.to include(" vb.customize ['createhd', '--filename', 'vm1-test_disk.vdi', '--size', '5120']") }
      it { is_expected.to include(" vb.customize ['storageattach', :id, '--storagectl', 'Beaker USB Controller', '--port', '0', '--device', '0', '--type', 'hdd', '--medium', 'vm1-test_disk.vdi']") }
    end

    context 'storage with the LSILogic controller' do
      let(:hosts) { make_hosts({:volumes => { 'test_disk' => { size: '5120' }}, :volume_storage_controller => 'LSILogic' }) }

      it { is_expected.to include(" vb.customize ['storagectl', :id, '--name', 'Beaker LSILogic Controller', '--add', 'scsi', '--portcount', '16', '--controller', 'LSILogic', '--bootable', 'off']") }
      it { is_expected.to include(" vb.customize ['createhd', '--filename', 'vm1-test_disk.vdi', '--size', '5120']") }
      it { is_expected.to include(" vb.customize ['storageattach', :id, '--storagectl', 'Beaker LSILogic Controller', '--port', '0', '--device', '0', '--type', 'hdd', '--medium', 'vm1-test_disk.vdi']") }
    end

    context "storage with the default controller" do
      let(:hosts) { make_hosts({:volumes => { 'test_disk' => { size: '5120' }}}) }

      it { is_expected.to include(" vb.customize ['storagectl', :id, '--name', 'Beaker IntelAHCI Controller', '--add', 'sata', '--portcount', '2', '--controller', 'IntelAHCI', '--bootable', 'off']") }
      it { is_expected.to include(" vb.customize ['createhd', '--filename', 'vm1-test_disk.vdi', '--size', '5120']") }
      it { is_expected.to include(" vb.customize ['storageattach', :id, '--storagectl', 'Beaker IntelAHCI Controller', '--port', '0', '--device', '0', '--type', 'hdd', '--medium', 'vm1-test_disk.vdi']") }
    end
  end

  context 'disabled vb guest plugin' do
    let(:options) { super().merge({ :vbguest_plugin => 'disable' }) }
    subject { vagrant.class.provider_vfile_section( hosts.first, options ) }

    it { is_expected.to match(/vb\.vbguest\.auto_update = false/) }
  end
end
