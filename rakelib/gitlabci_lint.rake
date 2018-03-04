
require 'net/http'
require 'uri'
require 'json'
require 'yaml'

def gitlab_ci_lint
  gitlab_ci_yml_path = ENV.fetch(
    'GITLAB_CI_YML_PATH',
    File.expand_path('../.gitlab-ci.yml', File.dirname(__FILE__)),
  )
  unless File.exists? gitlab_ci_yml_path
    warn "WARNING: no GitLab CI config found at '#{gitlab_ci_yml_path}'"
    warn '(skipping)'
    return
  end

  gitlab_ci_url = ENV['GITLAB_CI_URL'] or abort(
    "ERROR: ENV key not found: GITLAB_CI_URL\n\n" +
    "Example:\n\n" +
    "    export GITLAB_CI_URL=https://gitlab.com/api/v4/ci/lint\n\n"
  )

  uri = URI.parse( gitlab_ci_url )
  request = Net::HTTP::Post.new(uri)
  request.content_type = "application/json"

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

  elsif JSON.parse(response.body).fetch('status','') != 'valid'
    msg =  "ERROR: #{File.basename(gitlab_ci_yml_path)} is not valid!\n\n"
    data = JSON.parse response.body
    data['errors'].each do |error|
      msg += "  * #{error}"
    end
    msg += "\n\n"
    msg += "Path: '#{gitlab_ci_yml_path}'\n"
  else
    puts "#{File.basename(gitlab_ci_yml_path)} is valid\n\n"
  end
  abort msg if msg
end

namespace :gitlab_ci do
  desc 'Check the .gitlab-ci.yml for errors'
  task :lint do
    gitlab_ci_lint
  end
end

