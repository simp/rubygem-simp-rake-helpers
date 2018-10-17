module Simp::BeakerHelpers::SimpRakeHelpers::PkgRpmHelpers

  require_relative 'build_user_helpers'
  include Simp::BeakerHelpers::SimpRakeHelpers::BuildUserHelpers

  # rake command string to run on hosts
  # passes on useful troubleshooting env vars
  def rake_cmd
    cmd = 'bundle exec rake'
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
    result.stdout.to_s.scan(rx_scriptlet_blocks) do
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
    result.stdout.to_s.scan(rx_trigger_blocks) do
      trigger=  triggers[$~[:trigger]] ||= { :count => 0 }
      trigger[:count]       += 1
      trigger[:content]      = $~[:content].strip
      trigger[:full_block]   = $~[:block]
      trigger[:bare_content] = trigger[:content].gsub(/^((--|#).*?[\r\n]+)/,'')
    end
    triggers
  end
end
