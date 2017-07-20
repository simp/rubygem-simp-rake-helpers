# == Class simpmod::service
#
# This class is meant to be called from simpmod.
# It ensure the service is running.
#
class simpmod::service {
  assert_private()

  service { $::simpmod::service_name:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true
  }
}
