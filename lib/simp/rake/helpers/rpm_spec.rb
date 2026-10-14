# frozen_string_literal: true

module Simp; end
module Simp::Rake; end

class Simp::Rake::Helpers
  module Simp::Rake::Helpers::RPMSpec
    require 'simp/rake/build/constants'

    include Simp::Rake::Build::Constants

    TEMPLATE_DIR = File.join(File.dirname(__FILE__), 'assets', 'rpm_spec')

    # The RPM spec template for a SIMP version: simp<N>.spec for the newest N
    # that does not exceed the version's major, so a new SIMP major keeps
    # using the previous template until it needs a different one. Without a
    # version, simpdefault.spec.
    def rpm_template(simp_version = nil)
      simp_version = ENV.fetch('SIMP_BUILD_version', simp_version)

      template_file = if simp_version
                        simp_main_version = simp_version.split('.').first.to_i
                        versioned = Dir.glob(File.join(TEMPLATE_DIR, 'simp[0-9]*.spec')).map do |file|
                          [File.basename(file)[%r{\d+}].to_i, file]
                        end
                        versioned.select { |major, _| major <= simp_main_version }.max_by(&:first)&.last
                      else
                        File.join(TEMPLATE_DIR, 'simpdefault.spec')
                      end

      raise "Error: Could not find template for SIMP version #{simp_version}" unless template_file && File.exist?(template_file)

      File.read(template_file)
    end
  end
end
