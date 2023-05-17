module Simp; end
module Simp::Ci; end

# Class that provides GitLab-CI-related methods
class Simp::Ci::Gitlab
  require 'yaml'
  require 'json'

  # base class for errors
  class Error < StandardError ; end

  # incorrectly configured GitLab job
  class JobError < Error ; end

  # incorrectly configured gitlab-ci.yml
  class LintError < Error ; end

  # @param component_dir Root directory of the component project
  def initialize(component_dir)
    @component_dir = component_dir
    @gitlab_config_file = File.join(@component_dir, '.gitlab-ci.yml')
    @gitlab_yaml = nil
    @acceptance_dir = File.join(@component_dir, 'spec', 'acceptance')
    @suites_dir = File.join(@acceptance_dir, 'suites')

    # for reporting purposes, just use the name of the component
    # directory as the component name
    @component = File.basename(component_dir)
  end

  # @return true when config is the hash for an acceptance test job
  def acceptance_job?(config)
    config.is_a?(Hash) &&
    config.has_key?('script') &&
    (config.has_key?('stage') && (config['stage'] == 'acceptance'))
  end

  # @return whether the project has any suite-based acceptance tests
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

  # @return path to a suite's nodeset YAML file if it exists or nil otherwise
  #
  # If the suite has no 'nodesets' directory, it will search for the
  # nodeset YAML in the global nodeset directory.
  #
  def find_nodeset_yaml(suite, nodeset)
    nodeset_yml = nil
    suite_nodesets_dir = File.join(@suites_dir, suite, 'nodesets')
    if Dir.exist?(suite_nodesets_dir)
      nodeset_yml = File.join(suite_nodesets_dir, "#{nodeset}.yml")
      nodeset_yml = nil unless File.exist?(nodeset_yml)
    else
      nodeset_yml = File.join(@acceptance_dir, 'nodesets', "#{nodeset}.yml")
      nodeset_yml = nil unless File.exist?(nodeset_yml)
    end
    nodeset_yml
  end

  # Loads .gitlab-ci.yml
  # @return Hash of GitLab configuration
  # @raise Simp::Ci::Gitlab::LintError if YAML is malformed
  def load_gitlab_yaml
    return @gitlab_yaml if @gitlab_yaml

    begin
      @gitlab_yaml = YAML.load_file(@gitlab_config_file, aliases: true)
    rescue Psych::SyntaxError => e
      msg = "ERROR: Malformed YAML: #{e.message}"
      raise LintError.new(msg)
    end

    @gitlab_yaml
  end

  # Validate GitLab acceptance test job specifications
  #
  # Verify each acceptance test job specifies both a valid suite and
  # a valid nodeset
  #
  # @raise Simp::Ci::Gitlab::JobError if validation fails.
  #   Validation will fail under the following conditions
  #   (1) an acceptance test job is missing the suite or nodeset
  #   (2) an acceptance test job contains an invalid suite or nodeset
  #
  def validate_acceptance_test_jobs
    return unless File.exist?(@gitlab_config_file)

    failures = []

    gitlab_yaml = load_gitlab_yaml
    gitlab_yaml.each do |key, value|
      next unless acceptance_job?(value)

      value['script'].each do |line|
        next unless line.include? 'beaker:suites'
        if line.include?('[')
          match = line.match(/beaker:suites\[([\w\-_]*)(,([\w\-_]*))?\]/)
          suite = match[1]
          nodeset = match[3]

          if ! valid_suite?(suite)
            failures << "#{@component} job '#{key}' uses invalid suite '#{suite}': '#{line}'"
          elsif nodeset.nil?
            failures << "#{@component} job '#{key}' missing nodeset: '#{line}'"
          elsif ! find_nodeset_yaml(suite, nodeset)
            failures << "#{@component} job '#{key}' uses invalid nodeset '#{nodeset}': '#{line}'"
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

  # Validate gitlab configuration
  #
  # Validation performed
  # - Verifies configuration file is valid YAML
  # --Verifies configuration file passes GitLab lint check, when connectivity
  #   to GitLab is available
  # - Verifies acceptance test job configuration has valid suites and nodesets
  # @raise Simp::Ci::Gitlab::Error upon any validation failure
  #
  def validate_config
    if File.exist?(@gitlab_config_file)
      validate_yaml
      validate_acceptance_test_jobs
    elsif acceptance_tests?
      # can't assume this is a failure, so just warn
      puts "WARNING:  #{@component} has acceptance tests but no .gitlab-ci.yml"
    end
  end

  # Verifies gitlab-ci.yml is valid YAML and, when possible, passes GitLab
  # lint checks
  # @raise Simp::Ci::Gitlab::LintError upon any failure
  def validate_yaml
    return unless File.exist?(@gitlab_config_file)

    # first check for malformed yaml
    gitlab_yaml = load_gitlab_yaml

    # apply GitLab lint check
    begin
      gitlab_config_json = gitlab_yaml.to_json
    rescue Exception => e
      # really should never get here....
      puts "WARNING: Could not lint check #{@component}'s GitLab configuration: query could not be formed"
      return
    end

    curl ||= %x(which curl).strip
    if curl.empty?
      puts "WARNING: Could not lint check #{@component}'s GitLab configuration: Could not find 'curl'"
      return
    end

    query = [
      curl,
      '--silent',
      '--header "Content-Type: application/json"',
      'https://gitlab.com/api/v4/ci/lint',
      '--data', "'{\"content\":#{gitlab_config_json.dump}}'"
    ]
    result = `#{query.join(' ')}`

    status = :unknown
    errors = nil
    begin
      result_hash = JSON.load(result)
      # if stdout is empty, result_hash will be nil
      unless result_hash.nil?
        if result_hash.has_key?('status')
          if result_hash['status'] == 'valid'
            status = :valid
          else
            status = :invalid
            errors = result_hash['errors']
          end
        end
      end

    rescue
      # stdout does not contain JSON...don't know what happened!
    end

    if status == :unknown
      puts "WARNING: Unable to lint check #{@component}'s GitLab configuration"
    elsif status == :invalid
      separator = "\n   "
      msg = "ERROR: Invalid GitLab config:#{separator}#{errors.join(separator)}"
      raise LintError.new(msg)
    end
  end


  def valid_suite?(suite)
    suite_dir = File.join(@suites_dir, suite)
    #TODO check for suites that have no tests?
    return Dir.exist?(suite_dir)
  end

end
