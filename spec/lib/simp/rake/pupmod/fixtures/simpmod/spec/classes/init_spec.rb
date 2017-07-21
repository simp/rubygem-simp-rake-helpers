require 'spec_helper'

describe 'simpmod' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simpmod') }
    it { is_expected.to contain_class('simpmod') }
    it { is_expected.to contain_class('simpmod::install').that_comes_before('Class[simpmod::config]') }
    it { is_expected.to contain_class('simpmod::config') }
    it { is_expected.to contain_class('simpmod::service').that_subscribes_to('Class[simpmod::config]') }

    it { is_expected.to contain_service('simpmod') }
    it { is_expected.to contain_package('simpmod').with_ensure('present') }
  end


  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        context "simpmod class without any parameters" do
          let(:params) {{ }}
          it_behaves_like "a structured module"
          it { is_expected.to contain_class('simpmod').with_trusted_nets(['127.0.0.1/32']) }
        end

        context "simpmod class with firewall enabled" do
          let(:params) {{
            :trusted_nets     => ['10.0.2.0/24'],
            :tcp_listen_port => 1234,
            :enable_firewall => true,
          }}
          ###it_behaves_like "a structured module"
          it { is_expected.to contain_class('simpmod::config::firewall') }

          it { is_expected.to contain_class('simpmod::config::firewall').that_comes_before('Class[simpmod::service]') }
          it { is_expected.to create_iptables__listen__tcp_stateful('allow_simpmod_tcp_connections').with_dports(1234)
          }
        end

        context "simpmod class with selinux enabled" do
          let(:params) {{
            :enable_selinux => true,
          }}
          ###it_behaves_like "a structured module"
          it { is_expected.to contain_class('simpmod::config::selinux') }
          it { is_expected.to contain_class('simpmod::config::selinux').that_comes_before('Class[simpmod::service]') }
          it { is_expected.to create_notify('FIXME: selinux') }
        end

        context "simpmod class with auditing enabled" do
          let(:params) {{
            :enable_auditing => true,
          }}
          ###it_behaves_like "a structured module"
          it { is_expected.to contain_class('simpmod::config::auditing') }
          it { is_expected.to contain_class('simpmod::config::auditing').that_comes_before('Class[simpmod::service]') }
          it { is_expected.to create_notify('FIXME: auditing') }
        end

        context "simpmod class with logging enabled" do
          let(:params) {{
            :enable_logging => true,
          }}
          ###it_behaves_like "a structured module"
          it { is_expected.to contain_class('simpmod::config::logging') }
          it { is_expected.to contain_class('simpmod::config::logging').that_comes_before('Class[simpmod::service]') }
          it { is_expected.to create_notify('FIXME: logging') }
        end
      end
    end
  end

  context 'unsupported operating system' do
    describe 'simpmod class without any parameters on Solaris/Nexenta' do
      let(:facts) {{
        :osfamily        => 'Solaris',
        :operatingsystem => 'Nexenta',
      }}

      it { expect { is_expected.to contain_package('simpmod') }.to raise_error(Puppet::Error, /Nexenta not supported/) }
    end
  end
end
