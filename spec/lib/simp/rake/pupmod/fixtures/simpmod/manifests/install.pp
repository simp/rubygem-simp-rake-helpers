# == Class simpmod::install
#
# This class is called from simpmod for install.
#
class simpmod::install {
  assert_private()

  package { $::simpmod::package_name:
    ensure => present
  }
}
