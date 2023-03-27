require 'git_utils'
require 'r10k_utils'
require 'master_manipulator'
test_name 'CODEMGMT-84 - C59271 - Attempt to Deploy with Invalid r10k Config'

#Init
env_path = on(master, puppet('config print environmentpath')).stdout.rstrip
git_repo_path = '/git_repos'
git_control_remote = File.join(git_repo_path, 'environments.git')
git_provider = ENV['GIT_PROVIDER'] || 'shellgit'
r10k_fqp = get_r10k_fqp(master)

r10k_config_path = get_r10k_config_file_path(master)
r10k_config_bak_path = "#{r10k_config_path}.bak"

#In-line files
r10k_conf = <<-CONF
cachedir: '/var/cache/r10k'
git:
  provider: '#{git_provider}'
sources:
  broken:
    dir: "#{env_path}"
    remote: "#{git_control_remote}"
CONF

#Verification
if get_puppet_version(master) < 4.0
  error_message_regex = /ERROR.*can\'t\ convert\ nil\ into\ String/
else
  error_message_regex = /ERROR.* -> no implicit conversion of nil into String/
end

#Teardown
teardown do
  step 'Restore Original "r10k" Config'
  on(master, "mv #{r10k_config_bak_path} #{r10k_config_path}")
end

#Setup
step 'Backup a Valid "r10k" Config'
on(master, "mv #{r10k_config_path} #{r10k_config_bak_path}")

step 'Update the "r10k" Config'
create_remote_file(master, r10k_config_path, r10k_conf)

#Tests
step 'Attempt to Deploy via r10k'
on(master, "#{r10k_fqp} deploy environment -v", :acceptable_exit_codes => 1) do |result|
  assert_match(error_message_regex, result.stderr, 'Expected message not found!')
end
