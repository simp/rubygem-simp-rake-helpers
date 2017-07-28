### 3.7.2 / 2017-07-20
* Updated rsync build dir to rsync_skeleton

### 3.7.1 / 2017-07-20
* Fixed bug in `:changelog_annotation` task
* `:test` now uses `:metadata_lint` instead of `:metadata`
* `:metadata` is now an alias for `:metadata_lint`
* Added tests and fixtures for changelog logic

### 3.7.0 / 2017-07-10
* Added compare_latest_tag task

### 3.6.0 / 2017-07-03
* Added changelog_annotation task

### 3.5.2 / 2017-06-16
* Fixed code count error

### 3.5.1 / 2017-05-15
* Fix ability to build with existing tarball

### 3.5.0 / 2017-03-17
* Updated dependencies to use Beaker 3

### 3.4.0 / 2017-03-17
* Added a Rake task `pkg:check_version` that can be run in any module to
  determine if it needs to have either the metadata.json or the CHANGELOG
  version bumped
* Should be looped and manually reviewed as a pre-build task

### 3.3.0 / 2017-02-28
* Modified to no longer add the SIMP Dev key into the GPGKEYS directory and
  instead add it to the root level of the DVD for local reference.

### 3.2.0 / 2017-02-02
* Updated gemspec deps to newer `simp-rake-helpers` ~> 1.0 and `rake` < 13.0

### 3.1.4 / 2017-02-01
* Updated requirement on `semantic_puppet`, which changed with Puppet 4.9+
* See: https://github.com/garethr/puppet-module-skeleton/pull/137/files

### 3.1.3 / 2016-12-02
* Fixed issues with looping through the build directories

### 3.1.2 / 2016-12-02
* Look for the DVD directory in the distribution directories

### 3.1.1 / 2016-11-29
* Fixed bug in legacy compatibility

### 3.1.0 / 2016-11-25
* Added SIMP 6 build structure support
* Fixed the detection for requiring rebuilds via mock

### 3.0.2 / 2016-11-02
* Added a lot more parallel capability
* Added a 'pkg:single' task for building single RPMs from the top level
* Added the ability to build puppet module RPM packages without requiring a fork

### 3.0.1 / 2016-10-28
* Updated to provide backwards compatibility for SIMP 4 and 5

### 3.0.0 / 2016-09-22
* Updated the RPM spec template to handle the new SIMP 6 requirements

### 2.5.6 / 2016-09-22
* Added thread safe failure checks
* Will raise an error when building the modules if one or more fails
* Ensure that the packages.yaml file is 'human clean'
* Made the repoclosure error detection more aggressive

### 2.5.5 / 2016-09-19
* Fixed bugs in Puppetfile.stable generation.

### 2.5.4 / 2016-09-12
* Several fixes for building on systems that are connected to the Red Hat
  Network directly. Tested on AWS.

### 2.5.3 / 2016-08-31
* Bumped the requirement for puppet-lint to >= 1.0 and < 3.0

### 2.5.2 / 2016-08-31
* Sanity check pkg:rpmsign for executable availability
* Update `mock_pre_check` sanity check to use `which()`

### 2.5.1 / 2016-08-30
* Fixed the RPM spec template so that it properly picks up the requires and
  release files
* This is a bit of a mess and needs to be completely refactored in the future

### 2.4.7 / 2016-08-14
* Removed unnecessary `deps:checkout` warnings from fresh (empty) checkouts

### 2.4.6 / 2016-08-11
* Fix a broken method call between `r10k` 2.4.0 and `R10KHelper.new()`
* Add `:insync` status to acceptable module statuses for `deps:checkout`

### 2.4.5 / 2016-08-03
* No longer run the recursive Bundle by default

### 2.4.4 / 2016-07-29
* Fixed a circular dependency potential in the requires for simplib and stdlib
* Updated the spec tests to work more cleanly

### 2.4.3 / 2016-07-22
* Update all packages to use a consistent naming scheme and obsolete all that
  came before.

### 2.4.2 / 2016-07-13
* Ensure that RPM names are properly structured between SIMP and non-SIMP RPMs
* Make sure that the install path is proper

### 2.4.1 / 2016-07-05
* Fixed a misnamed variable causing build failures

### 2.4.0 / 2016-06-29
* Add a Lua-based RPM template to the build stack allowing us to build *any*
  Puppet module as an RPM without forking.

### 2.3.2 / 2016-06-29
* Force a useful failure on repoclosure issues

### 2.3.1 / 2016-06-27
* Translate 'RedHat' into 'RHEL' to match the file artifacts on disk.

### 2.3.0 / 2016-06-22
* Move 'listen' into the runtime dependencies so that 'guard' stops trying to
  yank it into a version that is not compatible with Ruby < 2.2.

### 2.2.0 / 2016-06-03
* Added support for the new LUA-based RPM spec files.
* Fixed a few bugs in some of the internal state checks.

### 2.1.2 / 2016-04-29
* Fixed runtime dependencies

### 2.1.1 / 2016-04-29
* Removed gem dependencies on ruby 2.2

### 2.1.0 / 2016-04-15
* ISOs will now build with EFI mode enabled
* The pkglist file will be read from the tarball during build:auto

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

