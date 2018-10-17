module Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers

  def copy_host_files_into_build_user_homedir(
    hosts,
    root_dir=File.expand_path('../../../',__FILE__)
  )
    # I've added the `ch* -R` on the SUT-side, which seems to work on a fresh checkout
    on hosts, 'cp -a /host_files /home/build_user/; ' +
             'find /home/build_user/host_files -type d \( ' +
               '-name dist -o -name junit -o -name log \) ' +
               '-exec chmod -R go=u-w {} \\; ; ' +
             'chown -R build_user:build_user /home/build_user/host_files; '
  end

end
