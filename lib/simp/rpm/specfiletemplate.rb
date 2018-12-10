module Simp; end
module Simp::Rpm; end

module Simp::Rpm::SpecFileTemplate

  # @returns Path of the SIMP Puppet module RPM spec file template
  #   appropriate for the version of SIMP specified.
  #
  #   If no SIMP version is specified, the path to the default spec
  #   file template will be returned.
  #
  # +simp_version+:: The version of SIMP
  #
  def spec_file_template(simp_version=nil)
    if simp_version
      simp_main_version = simp_version.split('.').first
    else
      simp_main_version = 'default'
    end

    template_file = File.join(File.dirname(__FILE__), 'assets', 'rpm_spec', "simp#{simp_main_version}.spec")

    raise "Error: Could not find template for SIMP version #{simp_version}" unless File.exist?(template_file)

    return template_file
  end
end
