### 2.0.1 / 2016-04-05
* Fix a bug where deps:checkout failed on unknown repos being present

### 1.0.13 / 2016-02-10
* Ensure that all rake tasks can run on EL6 systems
* Update the processing of RPM spec files to properly handle macros in target builds

### 1.0.12 / 2015-11-13
* Ensure that openssl, openssl-devel, and vim-enhanced are installed in mock by
  default

### 1.0.11 / 2015-07-30
* Allow simp/rpm to be used independently of Rake
* Ensure that packages are not re-signed that have already been signed by the
  presented key.
* Worked around an issue where rpm --resign will prompt more than once for the
  GPG key using the latest GPG version. This happens on the command line as
  well.

### 1.0.10 / 2015-07-23
* Relax dependency to allow puppet 3 or above

### 1.0.9 / 2015-07-15
* Ensure that the GPG signing code works on Fedora 22 and RHEL7 and RHEL6

### 1.0.8 / 2015-07-06
* Raise an error if the GPG signing command fails.

### 1.0.7 / 2015-06-27
* Ensure that the 'Release' variable doesn't pick up anything that's dynamic in
  nature.
* Optimized the build check code. Sped up pretty much everything.

### 1.0.6 / 2015-06-24
* Cleanup gemspec
* Fixed bugs in the RPM signing code regarding fetching the username and
  password from the appropriate source.

### 1.0.4 / 2015-06-22
* Added support for reading information directly from RPMs as well as spec
  files.

### 1.0.2 / 2105-04-02
* Added support for snapshot_release, adds date and time to rpm release
  version

### 1.0.1 / 2015-02-03
* Added the top level rake and rpm files to the Manifest

### 1.0.0 / 2014-12-09
* Refactored all the SIMP repositories' common Rakefile tasks into this gem.
  * Birthday!

