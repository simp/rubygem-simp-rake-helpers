vagrant rsync
vagrant ssh -c "cd /vagrant; bundle --local || bundle; source spec/acceptance/support/development/rerun_acceptance_tests.sh" -- -v

echo
echo ==================
echo
echo 'In order to troubleshoot directly on a container:'
echo
echo '  vagrant ssh                           # enter vagrant VM'
echo '  docker ps                             # identify container to inspect'
echo '  docker exec -it $CONTAINER_ID bash    # log into container'
echo
echo '  source /host_files/spec/acceptance/development/docker_env.sh  '
echo '    # or, to start testing a particular script'
echo '   source /home/build_user/host_files/spec/acceptance/files/testpackage_custom_scriptlet'
echo
echo ' ru "rpm -q --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n' --specfile $TWD/dist/tmp/testpackage_custom_scriptlet.spec"'
