vagrant rsync
vagrant ssh -c "cd /vagrant; bundle --local || bundle; ls -l; source /vagrant/spec/acceptance/development/rerun_acceptance_tests.sh" -- -v


[[ $? -eq 0 ]] && status=SUCCESS || status=FAILED
echo
echo ==================
echo     $status
echo ==================
echo
echo 'In order to troubleshoot directly on a container:'
echo
echo '  vagrant ssh                           # enter vagrant VM'
echo '  docker ps                             # identify container to inspect'
echo '  docker exec -it el6-build-server bash # log into container (example: el6-build-server)'
echo
echo '  source /host_files/spec/acceptance/development/docker_env.sh  '
echo
echo '    # or, to start testing a particular script'
echo
echo ' source /host_files/spec/acceptance/development/docker_env.sh /home/build_user/host_files/spec/acceptance/files/custom_scriptlet_triggers/pupmod-new-package-2.0'
echo
echo ' ru "rpm -q --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n' --specfile $TWD/dist/tmp/testpackage_custom_scriptlet.spec"'
