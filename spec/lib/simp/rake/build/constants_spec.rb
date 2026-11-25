# frozen_string_literal: true

require 'simp/rake'
require 'simp/rpm'
require 'simp/rake/build/constants'
require 'spec_helper'

describe Simp::Rake::Build::Constants do
  subject(:obj) do
    Class.new { include Simp::Rake::Build::Constants }.new.tap do |o|
      o.init_member_vars(File.expand_path('../../files/simp_build', __dir__))
    end
  end

  around(:each) do |example|
    saved = ENV.to_h.slice('SIMP_BUILD_distro', 'SIMP_RPM_dist')
    ENV.delete('SIMP_BUILD_distro')
    ENV['SIMP_RPM_dist'] = '.el9'
    example.run
  ensure
    ENV.delete('SIMP_BUILD_distro')
    ENV.delete('SIMP_RPM_dist')
    ENV.update(saved)
  end

  it 'builds AlmaLinux from the RedHat tree, by OS family' do
    allow(Facter).to receive(:value).and_call_original
    allow(Facter).to receive(:value).with(:os).and_return(
      'name' => 'AlmaLinux', 'family' => 'RedHat', 'architecture' => 'x86_64', 'release' => { 'major' => '9' },
    )

    expect(obj.instance_variable_get(:@build_distro)).to eq 'RedHat'
    expect(obj.instance_variable_get(:@build_version)).to eq '9'
    expect(obj.instance_variable_get(:@build_arch)).to eq 'x86_64'
  end

  it 'still honors SIMP_BUILD_distro' do
    ENV['SIMP_BUILD_distro'] = 'CentOS/8/x86_64'
    expect(obj.instance_variable_get(:@build_distro)).to eq 'CentOS'
    expect(obj.instance_variable_get(:@build_version)).to eq '8'
  end
end
