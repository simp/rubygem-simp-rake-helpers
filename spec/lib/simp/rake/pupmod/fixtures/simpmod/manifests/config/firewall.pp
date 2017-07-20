# == Class simpmod::config::firewall
#
# This class is meant to be called from simpmod.
# It ensures that firewall rules are defined.
#
class simpmod::config::firewall {
  assert_private()

  # FIXME: ensure your module's firewall settings are defined here.
  iptables::listen::tcp_stateful { 'allow_simpmod_tcp_connections':
    trusted_nets => $::simpmod::trusted_nets,
    dports       => $::simpmod::tcp_listen_port
  }
}
