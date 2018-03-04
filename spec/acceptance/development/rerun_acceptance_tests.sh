#!/bin/bash

# Run this from your docker host to wipe out all containers and restart beaker
# tests.

# Find & kill running beaker containers
(docker ps -a | grep -v CONT | awk '{print "docker kill " $1 "; docker rm " $1}') > /tmp/x.$$
source /tmp/x.$$ && rm /tmp/x.$$

if [[ $# -gt 0 ]]; then
  BEAKER_destroy=no SIMP_RPM_LUA_debug=yes SIMP_RAKE_PKG_verbose=yes SIMP_RPM_verbose=yes $@
else
  # re-run acceptance tests
  BEAKER_destroy=no SIMP_RPM_LUA_debug=yes SIMP_RAKE_PKG_verbose=yes SIMP_RPM_verbose=yes bundle exec rake acceptance
fi
