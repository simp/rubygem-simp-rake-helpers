module Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers

  # rake command string to run on hosts
  # passes on useful troubleshooting env vars
  def rake_cmd
    cmd = 'rake'
    %w(
      SIMP_RPM_LUA_debug
      SIMP_RAKE_PKG_verbose
      SIMP_RPM_verbose
    ).each do |env_var|
      if value = ENV[env_var]
         cmd = "#{env_var}=#{value} #{cmd}"
      end
    end
    cmd
  end


  def copy_host_files_into_build_user_homedir(
    hosts,
    root_dir=File.expand_path('../../../',__FILE__)
  )
    # make sure all generated files from previous rake tasks have
    # permissions that allow the copy in the 'prep' below
    #
    # FIXME: ^^^ This doesn't make sense to me, since it modifies the file
    #        permissions on the host *after* they've been uploaded to the SUTs.
    #
    #        I've added a `cp -a` + `chown/chmod -R` in the section below, which
    #        seems to accomplish what this is documented as doing.
    #
    #        So: Is this section still needed for something?
    #
    #          * If `no`:  let's remove it
    #          * If `yes`: let's demonstrate + document it
    #          * If you'd rather try something else, turn to page 386
    #
    dist_dirs = Dir.glob(File.join(root_dir, '**', 'dist'))
    dist_dirs.each { |dir| FileUtils.chmod_R(0755, dir) }
    FileUtils.chmod_R(0755, 'junit')
    FileUtils.chmod_R(0755, 'log')

    # I've added the `ch* -R` on the SUT-side, which seems to work on a fresh checkout
    on hosts, 'cp -a /host_files /home/build_user/; ' +
             'chmod -R go=u-w /home/build_user/host_files/{dist,**/dist,junit,log}; ' +
             'chown -R build_user:build_user /home/build_user/host_files; '
  end


  # key   = what `rpm -q --scripts` calls each scriptlet
  # value = the label passed to `simp_rpm_helper`
  def scriptlet_label_map
    {
      'pretrans'      => nil,
      'preinstall'    => 'pre',
      'postinstall'   => 'post',
      'preuninstall'  => 'preun',
      'postuninstall' => 'postun',
      'posttrans'     => nil,
    }
  end


  # returns a Hash of information about an RPM file's scriptlets
  def rpm_scriptlets_for( host, rpm_file )
    _labels  = scriptlet_label_map.keys.join('|')
    rx_scriptlet_blocks = /^(?<block>(?<scriptlet>#{_labels}) scriptlet.*?(\r|\n)(?<content>.*?))(?=\n#{_labels}|\Z)/m

    result = on host, %Q(rpm -qp --scripts #{rpm_file})

    scriptlets = {}
    result.stdout.scan(rx_scriptlet_blocks) do
      scriptlet = scriptlets[$~[:scriptlet]] ||= { :count => 0 }
      scriptlet[:count]       += 1
      scriptlet[:content]      = $~[:content].strip
      scriptlet[:full_block]   = $~[:block]
      scriptlet[:bare_content] = scriptlet[:content].gsub(/^((--|#).*?[\r\n]+)/,'')
    end
    scriptlets
  end


  # returns a Hash of information about an RPM file's triggers
  def rpm_triggers_for( host, rpm_file )
    _trigger          = 'trigger\\w+ scriptlet \\(using [\\/a-z0-9]+\\) --(!?\\p{Graph}|\\s)*?'
    rx_trigger_blocks = /^(?<block>(?<trigger>#{_trigger})[\r\n](?<content>.*?)(?=\n#{_trigger}|\Z))/m

    result = on host, %Q(rpm -qp --triggers #{rpm_file})

    triggers = {}
    result.stdout.scan(rx_trigger_blocks) do
      trigger=  triggers[$~[:trigger]] ||= { :count => 0 }
      trigger[:count]       += 1
      trigger[:content]      = $~[:content].strip
      trigger[:full_block]   = $~[:block]
      trigger[:bare_content] = trigger[:content].gsub(/^((--|#).*?[\r\n]+)/,'')
    end
    triggers
  end
end
