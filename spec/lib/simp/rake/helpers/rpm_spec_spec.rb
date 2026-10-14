# frozen_string_literal: true

require 'simp/rake/helpers/rpm_spec'
require 'spec_helper'

describe Simp::Rake::Helpers::RPMSpec do
  subject(:helper) { Class.new { include Simp::Rake::Helpers::RPMSpec }.new }

  let(:template_dir) { Simp::Rake::Helpers::RPMSpec::TEMPLATE_DIR }
  let(:simp6_template) { File.read(File.join(template_dir, 'simp6.spec')) }
  let(:default_template) { File.read(File.join(template_dir, 'simpdefault.spec')) }

  around(:each) do |example|
    saved = ENV.delete('SIMP_BUILD_version')
    example.run
  ensure
    saved.nil? ? ENV.delete('SIMP_BUILD_version') : ENV['SIMP_BUILD_version'] = saved
  end

  it 'uses the template for the exact SIMP major' do
    expect(helper.rpm_template('6.6.0-2')).to eq(simp6_template)
  end

  it 'falls back to the newest older template for a newer SIMP major' do
    expect(helper.rpm_template('7.0.0-Alpha.el8')).to eq(simp6_template)
  end

  it 'prefers SIMP_BUILD_version over the argument' do
    ENV['SIMP_BUILD_version'] = '7.0.0-Alpha.el10'
    expect(helper.rpm_template('5.0.0')).to eq(simp6_template)
  end

  it 'uses the default template without a SIMP version' do
    expect(helper.rpm_template).to eq(default_template)
  end

  it 'fails for a SIMP major older than every template' do
    expect { helper.rpm_template('5.4.0') }.to raise_error(%r{Could not find template for SIMP version 5\.4\.0})
  end
end
