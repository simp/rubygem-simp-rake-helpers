module Simp; end
module Simp::Ci; end

# Class that provides GitLab-CI-related methods
class Simp::Ci::Gitlab
  class JobError < StandardError ; end

  # Validate GitLab acceptance test job specifications
  #
  # Verify each acceptance test job specifies both a valid suite and
  # a valid nodeset
  #
  # This task will fail under the following conditions
  # (1) an acceptance test job is missing the suite or nodeset
  # (2) an acceptance test job contains an invalid suite or nodeset
  #
  # @param component_dir The root directory of the component project.
  #
  def self.validate_acceptance_test_jobs(component_dir)
    gitlab_config_file = File.join(component_dir, '.gitlab-ci.yml')
    return unless File.exist?(gitlab_config_file)

    component = File.basename(component_dir)
    failures = []
    gitlab_yaml = YAML.load(File.read(gitlab_config_file))
    gitlab_yaml.each do |key,value|
      next unless (value.is_a?(Hash) && value.has_key?('script'))
      next unless (value.has_key?('stage') && (value['stage'] == 'acceptance'))

      value['script'].each do |line|
        next unless line.include? 'beaker:suites'
        if line.include?('[')
          match = line.match(/beaker:suites\[([\w\-_]*)(,([\w\-_]*))?\]/)
          suite = match[1]
          nodeset = match[3]

          suite_dir = File.join(component_dir, 'spec', 'acceptance', 'suites', suite)
          unless Dir.exist?(suite_dir)
            failures << "#{component} job '#{key}' uses invalid suite '#{suite}': '#{line}'"
          end

          if nodeset.nil?
            failures << "#{component} job '#{key}' missing nodeset: '#{line}'"
          else
            nodeset_yml = "#{component_dir}/spec/acceptance/suites/#{suite}/#{nodeset}.yml"
            unless File.exist?(nodeset_yml)
              nodeset_yml = "#{component_dir}/spec/acceptance/nodesets/#{nodeset}.yml"
              unless File.exist?(nodeset_yml)
                nodeset_yml = nil
              end
            end

            unless nodeset_yml
              failures << "#{component} job '#{key}' uses invalid nodeset '#{nodeset}': '#{line}'"
            end
          end
        else
          failures <<  "#{component} job '#{key}' missing suite and nodeset: '#{line}'"
        end
      end
    end

    unless failures.empty?
      separator = "\n   "
      msg = "Invalid GitLab acceptance test config:#{separator}#{failures.join(separator)}"
      raise JobError.new(msg)
    end
  end

end
