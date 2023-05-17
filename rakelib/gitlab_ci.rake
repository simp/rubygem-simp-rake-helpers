require 'net/http'
require 'uri'
require 'json'
require 'yaml'


def gitlab_ci_lint( gitlab_ci_url, gitlab_ci_yml_path )
  unless File.exist? gitlab_ci_yml_path
    warn "WARNING: no GitLab CI config found at '#{gitlab_ci_yml_path}'"
    warn '(skipping)'
    return
  end

  puts "Querying #{gitlab_ci_url} ...\n\n"  if $VERBOSE
  uri = URI.parse( gitlab_ci_url )
  request = Net::HTTP::Post.new(uri)
  request.content_type = "application/json"
  request['PRIVATE-TOKEN'] = ENV['GITLAB_API_TOKEN'] || fail('Missing env var: GITLAB_API_TOKEN')

  content = YAML.load_file(gitlab_ci_yml_path)
  request.body = JSON.dump({ "content" => content.to_json })
  req_options = {
    use_ssl: uri.scheme == "https",
  }
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  if response.code_type != Net::HTTPOK
    msg =  "ERROR: Could not use CI linter at #{gitlab_ci_url} " +
           "(#{response.code}: #{response.message})\n\n"

  elsif JSON.parse(response.body)['valid']
    puts "#{File.basename(gitlab_ci_yml_path)} is valid\n\n"
  else
    msg =  "ERROR: #{File.basename(gitlab_ci_yml_path)} is not valid!\n\n"
    data = JSON.parse response.body
    data['errors'].each do |error|
      msg += "  * #{error}\n"
    end
    msg += "\n\n"
    msg += "Path: '#{gitlab_ci_yml_path}'\n"

    msg
  end
  abort msg if msg
end


namespace :gitlab_ci do
  desc <<~MSG
    Check the .gitlab-ci.yml for errors

    Arguments:

    * gitlab_url          ex: https://gitlab.com
                          env var default: `GITLAB_URL`
    * project_id          ex: group-name/project-name
                          env var default: `GITLAB_PROJECT`
    * gitlab_ci_yml_path  default: .gitlab-ci.yml
                          env var: `GITLAB_CI_YML_PATH`

    If `gitlab_url` and `project_id` are not provided by argument or env var,
    the task will look for a .gitlab-project-api.yaml file with those keys
  MSG
  task :lint, [:gitlab_url, :project_id]  do |t, args|
    args.with_defaults(
      gitlab_url: ENV['GITLAB_URL'],
      project_id: ENV['GITLAB_PROJECT'],
      gitlab_ci_yml_path: (ENV['GITLAB_CI_YML_PATH'] || '.gitlab-ci.yml')
    )
    gitlab_url         = args.gitlab_url
    project_id         = args.project_id
    gitlab_ci_yml_path = args.gitlab_ci_yml_path

    unless(gitlab_url && project_id)
      warn 'WARNING: no gitlab_url or project_id given via task arg or env var' if $VERBOSE
      warn 'Checking for .gitlab-project-api.yaml...' if $VERBOSE
      unless File.exist? '.gitlab-project-api.yaml'
        fail( [
          "\nERROR: no gitlab_url or project_id given via task arg or env va
r",
          "and no .gitlab-project-api.yaml file found\n",
          "FATAL: Task must be given values for #{args.names}",
          "       See `rake D #{t.name}` for details\n\n",
        ].join("\n"))
      else
        require 'yaml'
        warb 'Reading .gitlab-project-api.yaml...' if $VERBOSE
        data = YAML.load_file('.gitlab-project-api.yaml')
        gitlab_url, project_id = data['gitlab_url'], data['project_id']
        project_id.gsub!('/','%2F')
        warn "Using data:", data.to_yaml if $VERBOSE
      end
    end

    gitlab_ci_yml_paths = gitlab_ci_yml_path.split(':')
    gitlab_ci_url = "#{gitlab_url}/api/v4/projects/#{project_id}/ci/lint"
    puts "CI Linting using GitLab URI: #{gitlab_ci_url}:" if $VERBOSE
    puts gitlab_ci_yml_paths.map{|x| "\t- #{x}\n"}.join, '' if $VERBOSE

    gitlab_ci_yml_paths.each do |g|
      gitlab_ci_lint(gitlab_ci_url, g)
    end

  end
end
