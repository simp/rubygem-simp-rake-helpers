vagrant rsync
vagrant ssh -c "cd /vagrant; bundle --local || bundle; source spec/acceptance/support/debugging/rerun_acceptance_tests.sh" -- -v
