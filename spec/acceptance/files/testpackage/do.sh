
# mimic the beaker setup:
rm -rf /home/build_user/host_files
cp -a /host_files /home/build_user/; chown -R build_user:build_user /home/build_user/host_files

export TERM=xterm
export TOPWD=/home/build_user/host_files
export TWD=/home/build_user/host_files/spec/acceptance/files/testpackage
export TWDSPEC="$TWD/dist/tmp/testpackage.spec"
alias  twd="cd $TWD"
rug(){
 runuser build_user -l -c "cd /$TOPWD; $@"
}
ru(){
 runuser build_user -l -c "cd /$TWD; SIMP_RPM_verbose=yes SIMP_PKG_verbose=yes $@"
}
ru_specfile_rpm_q(){
  ru "rpm -q -D 'pup_module_info_dir $TWD' --specfile $TWD/dist/tmp/testpackage.spec $@"
}

# Ensure the new gem is on the system
rug "bundle update --local || bundle update"
rug "rake clean"
rug "rake pkg:install_gem"
ru "gem cleanup"


# mimic the beaker setup:
ru "rvm use default; bundle update"
ru "rake clean"
ru "rpm -q -D 'pup_module_info_dir $TWD' --specfile $TWD/dist/tmp/testpackage.spec"
ru "rake pkg:rpm"  && ru "find dist -name \*noarch.rpm -ls; date" && rpm -qip $TWD/dist/pupmod-simp-testpackage-0.0.1-0.noarch.rpm
