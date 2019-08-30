module Simp; end
module Simp::Ci; end

# Class that provides GitLab-CI-related methods
class Simp::Ci::Gitlab
  # incorrectly configured GitLab job
  class JobError < StandardError ; end

  # @param component_dir The root directory of the component project.
  def initialize(component_dir)
    @component_dir = component_dir
    @acceptance_dir = File.join(@component_dir, 'spec', 'acceptance')
    @suites_dir = File.join(@acceptance_dir, 'suites')

    # for reporting purposes, just use the name of the component
    # directory as the component name
    @component = File.basename(component_dir)
  end

  # @return whether the project has any suite-based acceptance tests
  #
  def acceptance_tests?
    tests_found = false
    suite_dirs = Dir.glob(File.join(@suites_dir, '*'))
    suite_dirs.delete_if { |x| ! File.directory?(x) }
    suite_dirs.each do |suite_dir|
      tests = Dir.glob(File.join(suite_dir, '*_spec.rb'))
      next if tests.empty?
      nodesets = Dir.glob(File.join(suite_dir, 'nodesets', '*.yml'))
      if nodesets.empty?
        nodesets = Dir.glob(File.join(@acceptance_dir, 'nodesets', '*.yml'))
      end
      unless nodesets.empty?
        tests_found = true
        break
      end
    end
    tests_found
  end

  # Validate GitLab acceptance test job specifications
  #
  # Verify each acceptance test job specifies both a valid suite and
  # a valid nodeset
  #
  # This task will fail under the following conditions
  # (1) an acceptance test job is missing the suite or nodeset
  # (2) an acceptance test job contains an invalid suite or nodeset
  #
  #
  def validate_acceptance_test_jobs
    gitlab_config_file = File.join(@component_dir, '.gitlab-ci.yml')
    unless File.exist?(gitlab_config_file)
      if acceptance_tests?
        puts "WARNING:  #{@component} has acceptance tests but no .gitlab-ci.yml"
      end
      return
    end

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

          suite_dir = File.join(@suites_dir, suite)
          unless Dir.exist?(suite_dir)
            failures << "#{@component} job '#{key}' uses invalid suite '#{suite}': '#{line}'"
          end

          if nodeset.nil?
            failures << "#{@component} job '#{key}' missing nodeset: '#{line}'"
          else
            nodeset_yml = File.join(suite_dir, "#{nodeset}.yml")
            unless File.exist?(nodeset_yml)
              nodeset_yml = File.join(@acceptance_dir, 'nodesets', "#{nodeset}.yml")
              unless File.exist?(nodeset_yml)
                nodeset_yml = nil
              end
            end

            unless nodeset_yml
              failures << "#{@component} job '#{key}' uses invalid nodeset '#{nodeset}': '#{line}'"
            end
          end
        else
          failures <<  "#{@component} job '#{key}' missing suite and nodeset: '#{line}'"
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
