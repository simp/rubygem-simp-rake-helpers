# frozen_string_literal: true

module Simp; end
module Simp::Rake; end

module Simp::Rake::Helpers::Simp::Rake::Helpers::RPMSpec
  require 'simp/rake/build/constants'

  include Simp::Rake::Build::Constants

  def rpm_template(simp_version = nil)
    simp_version = ENV.fetch('SIMP_BUILD_version', simp_version)

    simp_main_version = if simp_version
                          simp_version.split('.').first
                        else
                          'default'
                        end

    template_file = File.join(File.dirname(__FILE__), 'assets', 'rpm_spec', "simp#{simp_main_version}.spec")

    raise "Error: Could not find template for SIMP version #{simp_version}" unless File.exist?(template_file)

    File.read(template_file)
  end
end
