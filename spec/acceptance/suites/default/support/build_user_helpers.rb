module Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers
  def build_user_homedir
    '/home/build_user'
  end

  def build_user_host_files
    "#{build_user_homedir}/host_files"
  end

  def copy_host_files_into_build_user_homedir(hosts, opts = {})
    commands = <<-COMMANDS.gsub(/^ {6}/,'')
      cp -aT /host_files #{build_user_host_files} ;
      find #{build_user_host_files} \\
        -type d -a \\( -name dist -o -name junit -o -name log \\) \\
        -exec chmod -R go=u-w {} \\; ;
      chown -R build_user:build_user #{build_user_host_files}
    COMMANDS
    on(hosts,commands,opts)
  end
end
