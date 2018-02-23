# Source this file within a docker container to set up convenience shell
# variables & functions.
#
# Usage:
#
#    source /host_files/spec/acceptance/support/debugging/docker_env.sh [DIR]
#
#    # testing a particular
#    source /host_files/spec/acceptance/support/debugging/docker_env.sh  /home/build_user/host_files/spec/acceptance/files/testpackage_custom_scriptlet
#
# ru "rpm -q --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n' --specfile $TWD/dist/tmp/testpackage_custom_scriptlet.spec"

#### [[ -z $1 ] then ]local $_twd=${1:-/home/build_user/host_files}

export TERM=xterm
export TOPWD=/home/build_user/host_files
export TOPWD_FILES=${TOPWD}/spec/acceptance/files
export TWD=${1:-$TOPWD_FILES/testpackage}
export TW=$(basename ${TWD})
export TWSPEC="$TWD/dist/tmp/testpackage.spec"
alias  twd="cd $TWD"
rug(){
 runuser build_user -l -c "cd /$TOPWD; $@"
}
ru(){
 runuser build_user -l -c "cd /$TWD; SIMP_RPM_LUA_debug=yes SIMP_RPM_verbose=yes SIMP_PKG_verbose=yes $@"
}
ru_specfile_rpm_q(){
  ru "rpm -q -D 'pup_module_info_dir $TWD' --specfile $TWD/dist/tmp/testpackage.spec $@"
}
