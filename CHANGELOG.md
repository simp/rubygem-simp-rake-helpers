### 5.24.0 / 2025-10-20
- Fixed
  - Update gem dependencies to allow simp-rspec-puppet-facts 4.x

### 5.23.0 / 2025-08-18
- Fixed
  - Adding renovate.json should not require a version bump (#225)

### 5.22.2 / 2025-08-13
- Fixed
  - Update gem dependencies to allow simp-beaker-helpers 2.x

### 5.22.1 / 2024-09-10
- Fixed
  - Update gem dependencies to allow puppetlabs_spec_helper 7.x

### 5.22.0 / 2023-08-24
- Added
  - `iso:build` now skips repoclosure unless `SIMP_BUILD_repoclosure=yes`

### 5.21.0 / 2023-08-24
- Fixed
  - Support for Ruby 3 and Puppet 8
  - Update gem dependencies

### 5.20.0 /2023-07-03
- Added
  - Support for `puppetlabs-spec-helper` 6.x and `puppet-lint`
    - New gem dependencies:
      - `metadata-json-lint`
      - `puppet-lint-params_empty_string-check`
  - Acceptance test/nodeset support for Puppet 8
  - Modernized GHA PR test matrix
- Changed
  - Default Puppet = 7.x
  - Default Ruby = 2.7
- Fixed
  - Don't fail when `metadata` task is not present
  - Untangled non-standard GHA workflows
  - Release workflow bug

### 5.19.1 / 2023-05-15
- Fixed
  - Bumped required puppet version to < 9.0
  - The base repo for the el7 ISO was unusable because the repodata for it
    was being excluded on the unpack of the distribution ISO; In the case
    of building an el7 iso, we now ensure the repodata directory exists.

### 5.19.1 / 2023-03-27
- Added
  - Allow `SIMP_BUILD_PKG_require_rebuild` to be case-insensitive to
    accommodate GHA

### 5.19.0 / 2023-03-20
- Added
  - `pkg:single` will skip the `require_rebuild?` logic
    when `SIMP_BUILD_PKG_require_rebuild=yes`
- Fixed
  - It was impossible to build simp-doc if RPM was published to yum repos; can
    now use `SIMP_BUILD_PKG_require_rebuild=yes`


### 5.18.0 / 2023-02-27
- Added
  - `SIMP_BUILD_reposync_only` now excludes RPMs and yum repos from the ISO
    `unpack` task
- Fixed
  - Change common repo name `base` to avoid repoclosure conflict warnings
  - EL7 ISO unpack no longer interferes with reposync repos when
    `SIMP_BUILD_reposync_only=yes`

### 5.17.1 / 2022-11-11
- Fixed
  - Fixed an edge case where the `SIMP` directory YUM metadata was not
    present if you used `reposync` for everything but the `SIMP` directory

### 5.17.0 / 2022-10-30
- Added
  - The RPM dependency file can now use `ignores` to remove items instead of
    needing to redefine the entire dependency stack to remove deps

### 5.16.0 / 2022-06-24
- Added
  - The `puppet-lint-optional_default-check` was added to prevent setting
    `Optional` parameters with default values.

### 5.15.0 / 2022-06-03
- Added
  - Users now have the ability to set version limits in the `dependencies.yaml`
    file that will override those in the `metadata.json`

### 5.14.0 / 2022-05-14
- Added
  - Run `implantisomd5` after the ISO has been created so that it can be
    validated by the installer at runtime.

### 5.13.3 / 2022-05-20
- Fixed:
  - Changed default RPM installed file permissions to 0644/0755
  - The tarball unpack exclusions were too aggressive. The `SIMP/GPGKEYS`
      directory is now preserved properly.

### 5.13.2 / 2022-05-13
- Fixed:
  - SIMP_BUILD_reposync_only now properly unpacks the tarball

### 5.13.1 / 2022-05-01
- Fixed:
  - Aligned wtih an API change in the `dirty?` method in `r10k`

### 5.13.0 / 2021-11-14
- Added:
  - Output the full `mkisofs` command when building an ISO
  - Added SIMP_BUILD_reposync_only to ignore the built tarball if a reposync
    directory is present

### 5.12.7 / 2021-10-26
- Added:
  - Env var `SIMP_PKG_progress_bar=no` to turn off pkg RPM build progress bars
  - Env var `SIMP_PKG_fetch_published_rpm=no` to prevent downloading a
    published package
- Fixed:
  - RPM builds no longer fail with leftover generated
    `build/rpm_metadata/releases` files
  - Removed unused code, tidied up some confusing bits to make structure more
    obvious

### 5.12.6 / 2021-10-19
- Ensure that the `Updates` directory does not link to files in itself

### 5.12.5 / 2021-10-07
- Fixed a bug where `build:auto` failed when building the SIMP ISO for EL7,
  because the code attempted to move a directory onto itself.
- Ensured GPG keys in simp-gpgkeys are available in the DVD overlay tar file

### 5.12.4 / 2021-10-05
- Ensure that the DIST qualifier is added to all built RPMs
- Use the new SimpRepos directory layout when building an ISO using externally
  copied repos.

### 5.12.3 / 2021-09-15
- Handle multiple options for required applications in build:auto
- Allow users to populate a `reposync` directory in the YUM build space that
  will overwrite any target directories on the ISO.
  - The SIMP tarball is unpacked after the copy so you always get the latest
    built artifacts.
  - Pruning will not occur if this technique is used since it is presumed that
    you are overwriting the data with authoritative content.
- Added a helpful tip about updating vermap.yaml
- Fixed the call to repoclosure if on a system with DNF
- Added support for EL8 to vermap.yaml

### 5.12.2 / 2021-06-22
- Change to '-1' from '-0' as the default RPM release

### 5.12.1 / 2021-05-27
- Default `@build_dir` to `@distro_build_dir` in build tasks
- Use  `file --keep-going` in the **unpack** task's ISO validation check.  This
  allows the check to work from EL8-based systems, where `ISO 9660 CD-ROM
  filesystem data` is not the first match.

### 5.12.0 / 2021-02-16
- Ensure that pkg:install_gem uses the correct documentation options for the
  version of Ruby in use.
- Disable brp-mangle-shebangs when building RPMs.
- Mitigated problem where gpg-agent daemon fails to start because
  its socket path is longer than 108 characters.
  - Changed the default location of the GPG keys directory used in the
    pkg:key_prep and pkg:signrpms Rake tasks to <base_dir>/.dev_gpgkeys.
  - Added a SIMP_PKG_build_keys_dir environment variable that overrides
    the default location of the GPG keys directory used in the
    pkg:key_prep and pkg:signrpms Rake tasks.
- Added SIMP_PKG_rpmsign_timeout environment variable that overrides
  default timeout in seconds to wait for an individual RPM signing
  operation to complete.
  - Default timeout is 30 seconds.
  - Most relevant when signing on RPMs on EL8 and the gpg-agent
    started by rpmsign fails to start, but rpmsign does not detect
    the failure and hangs.
- Improved pkg:signrpms error handling and reporting.
- Fixed bug in GPG handling for GPG 2.1+ in which an existing
  GPG key that was not cached internally was not detected.
- Fixed bug where pkg:signrpms failed to sign RPMs on EL8.
- Fixed bug where pkg:checksig reported failure on EL8, even when
  the signatures were valid.
- Deprecated the following top-level Rake tasks for Puppet modules:
  - compare_latest_tag: use pkg:compare_latest_tag instead
  - changelog_annotation: use pkg:create_tag_changelog instead

### 5.11.6 / 2021-02-03
* Fix GPG handling for GPG 2.1+

### 5.11.5 / 2020-12-02
* Add support for Puppet 7
* Work around issues with querying RPM spec file changelogs using RPM version 4.15.0+
* Switch between 'with_unbundled_env' and 'with_clean_env' based on which one
  Bundler supports.

### 5.11.4 / 2020-08-03
* Permit *.md files in `rake pkg:compare_latest_tag`

### 5.11.3 / 2020-05-19
* Fix automatically added dependencies for SIMP 6.4+

### 5.11.2 / 2020-04-08
* Version information should not be required on dependencies in metadata.json

### 5.11.1 / 2020-04-07
* Puppet module RPM logic handles `-rc0` suffix in `metadata.json`

### 5.11.0 / 2020-03-16
* Add SIMP optional dependencies to RPM requires list

### 5.10.2 / 2020-02-10
* Allow v3 of simp-rspec-puppet-facts
* Fix '~> 0' notation

### 5.10.1 / 2019-12-03
* Don't fail upon first error encountered, when processing items in
  pkg:check_published.  Attempt as many checks as possible and then
  report all failures.

### 5.10.0 / 2019-08-30
* Add initial linting tasks for CI configuration (simp:ci_lint and
  simp:gitlab_ci_lint).  The only checks currently being done are
  as follows:
  * verifies the .gitlab-ci.yml is valid YAML
  * verifies the .gitlab-ci.yml passes GitLab lint checks
  * verifies each acceptance test job in the .gitlab-ci.yml fully
    specifies the suite and nodeset to be used and that the specified
    suite and nodeset exist.

### 5.9.1 / 2019-08-06
Fixed 2 bugs in the SIMP Puppet module generated RPM spec files
* When SIMP Puppet module RPMs were installed, they created the wrong
  state directory, '/%{_localstatedir}/lib/rpm-state/simp-adapter'.
  This incorrect directory was created because the ``_localstatedir``
  RPM macro was not evaluated at run time.
* The %preun and $postun scriptlet comments were incorrect.

### 5.9.0 / 2019-05-31
* Increase the upper bound of the Bundler dependency to < 3.0

### 5.8.3 / 2019-05-15
* Fix the package check to handle building different versions of SIMP

### 5.8.2 / 2019-05-02
* Update the list of packages to check for before building
  the tar file.

### 5.8.1 / 2019-04-01
* Update the upperbound of r10k runtime dependency

### 5.8.0 / 2019-02-14
* Add SIMP_BUILD_update_packages to allow users to update the packages.yaml
* file at build time if desired.
* Bump upper bound on puppet to < 7
* Add rakelib/ to the list of non-mission files/directories
  to exclude when comparing with the latest tag in
  pkg:compare_latest_tag and compare_latest_tag

### 5.7.1 / 2018-12-10
* Fix long standing logic issues that were causing download failures

### 5.7.0 / 2018-12-05
* Move use of simp_rpm_helper from %post to %postrans, to fix
  a bug in which files that should have been removed from the old
  version during RPM upgrade are copied.

### 5.6.3 / 2018-10-30
* Add information about the distribution OS to the simp-packer `vars.json`.
* Add builder version information to the simp-packer `vars.json`.
* Refactor writing the vars.json to its own method.

### 5.6.2 / 2018-10-02
* Refactor 'dev' GPG signing key logic into `Simp::LocalGpgSigningKey`
* Add acceptance tests for GPG logic and `rake pkg:signrpms`

### 5.6.1 / 2018-10-01
* Ensure that modules do not contain symlinks per the standard Puppet guidance.
* Do not try to only use the system cache for yum operations since this
  silently causes all EL6 builds to be rebuilt and can't really work anyway
  since there isn't a local cache unitl after yum runs. After yum runs, the
  local cache will be preferred unless it has expired anyway.

### 5.6.0 / 2018-09-09
* Add support for Beaker 4

### 5.5.3 / 2018-08-28
* Fix issue where the `pkg:signrpms` rake task would not honor 'force'
* Add a check for the existence of /usr/local/sbin/simp_rpm_helper, before
  running it in the latest Puppet-module RPM spec file.

### 5.5.2 / 2018-08-21
* Add additional UEFI support options to the ISO build based on user feedback.
  All of our testing could use the ISO on different UEFI systems successfully
  but apparently there can be vendor differences and this solves at least one
  of them.

### 5.5.1 / 2018-07-09
* It is possible to build RPMs for other OSes again (broken since 5.0.0)
* Fix regression that broke env var `SIMP_BUILD_distro`
* Add env var `SIMP_RPM_dist` to `SIMP::RPM` to target a specific `dist` while
  building RPMs from spec files.
* During a `rake build:auto`, the information from env var `SIMP_BUILD_distro`
  is used to set `SIMP_RPM_dist`
* Remove the dependency pin attempt on fog-openstack since this is handled by
  the simp-beaker-helpers dependency
* Update pkg:create_tag_change to verify all CHANGELOG entries for a component
  are in reverse chronological order, not just the entries for the latest
  version.
* Add pkg:check_rpm_changelog task to verify the 'rpm' command can parse a
  component's changelog.

### 5.5.0 / 2018-06-22
* Pin fog-openstack to 0.1.25 if Ruby is prior to 2.2.0 due to a deprecation
* Fix regression that broke env var `SIMP_BUILD_distro`
* Add support for setting SIMP_RSPEC_PUPPETFILE and/or SIMP_RSPEC_MODULEPATH to
  create a custom fixtures.yml based on a Puppetfile, the modules in a
  directory, or the combination of both.

### 5.4.3 / 2018-03-29
* Fix RPM release processing when generating 'Obsoletes' metadata

### 5.4.2 / 2018-03-06
* Document requirement for double-digit day in CHANGELOG date.
* Add optional spec test for CHANGELOG file at `$SIMP_SPEC_changelog`
* Fix invalid `module_without_changelog` spec test for `Simp::RelChecks`
* `load_and_validate_changelog` now passes on `verbose` to `Simp::ComponentInfo`

### 5.4.1 / 2018-03-04
* Fix Travis CI deployment script

### 5.4.0 / 2018-02-12
* Add support for RPM customization (e.g., scriptlets, triggers)
  - Scans new location `build/rpm_metadata/custom/` to find new content to
    inject into the RPM spec (e.g., scriptlets, triggers).
  - There is logic to permit overriding the `%pre`/`%post`/`%preun`/`%postun`
    default scriptlets.
* Enable `%triggerpostun` fix for SIMP-3895
  - The custom scriptlet feature provides a means for module RPMs that obsolete
    the same module name to introduce a `%triggerpostun -- <obsoleted-package>`
    scriptlet as a workaround to prevent `simp_rpm_helpers` from deleting
    everything.
  - The acceptance tests specifically demonstrate this type of trigger
* Improve RPM build troubleshooting:
  - New env var: `SIMP_RPM_verbose=yes`
  - New env var: `SIMP_RAKE_PKG_verbose=yes`
* Improve `simpdefault.spec` RPM Lua code troubleshooting:
  - Cleaned up header documentation
  - Added optional stderr warnings
  - Refactored (some) code into functions
  - Improved error messages
* Improve acceptance test / development workflow
  - Add `Vagrantfile` to provide a quick & pristine beaker/docker setup
* Refactor acceptance test structure
  - Code formerly embedded in the `pkg_rpm` tests have been refactored into
    common helpers that other tests can use.
  - There are mock prereq RPMs to test installation of newly-built RPMs
  - A `simp_rpm_helper` (a copy of the script in simp-adapter) for scenarios
* Update README.md
  - Removed obsolete references to `mock`-based development
  - Clarified RPM Generation documentation

### 5.3.1 / 2018-02-18
* Add a conditional check so simp-core can build an ISO with a
  pre-existing tarball with no user input

### 5.3.0 / 2018-02-02
* Add ability to specify external, non-module, RPM dependencies for
  a checked-out repo from `simp-core/build/rpm/dependencies.yaml`

### 5.2.0 / 2017-12-20
* Create pkg:create_tag_changelog, which is a more thorough version
  of Simp::Rake::Pupmod::Helpers changelog_annotation task.
  - Now supports non-Puppet SIMP assets for which version and changelog
    information is specified in an RPM spec files.
  - Provides more extensive validation of date strings and changelog
    entry ordering.
  - Stops processing at the first invalid changelog entry, to minimize
    non-catastrophic errors from old changelog entries.
* Create pkg:compare_latest_tag, which is a more general replacement
  for the Simp::Rake::Pupmod::Helpers compare_latest_tag task.
  - Now supports non-Puppet SIMP assets for which version and changelog
    information is specified in an RPM spec files.
  - Does the same validation as the new pkg:create_tag_changelog task.
* Fix broken acceptance tests
  - Remove logic to build SIMP 4 and SIMP 5 RPMs.
  - Remove mock logic

### 5.1.4 / 2017-11-27
* Switch back to using Gem::Version.new instead of Puppet's vercmp since
  Gem::Version matches the standard RPM version semantics and Puppet does not.

### 5.1.3 / 2017-10-16
* Ensure that the first package run uses the existing Bundle environment and
  falls back to a clean Bundle environment on failure.

### 5.1.2 / 2017-10-06
* Fixed 'Obsoletes' in the RPM spec files

### 5.1.1 / 2017-10-04
* Renamed 'RHEL' to 'RedHat' in the 'unpack' task for compatibility with the
  rest of the new code base

### 5.1.0 / 2017-10-03
* Fixed bug in `deps:record` that prevented recording to Puppetfile.[:method]
* Added new `:reference` parameter to `deps:record` for identifying repos to
  record

### 5.0.2 / 2017-10-03
* Determine the build/rpm_metadata/* files when the pkg:rpm
  rake task is called, not when the rake object is constructed.
  This is required for simp-doc RPM building.

### 5.0.1 / 2017-09-28
* Removed rpmkeys and rpmspec from the required list of commands,
  as they are not present in CentOS 6 and are automatically
  installed when the required rpmbuild command is installed in
  CentOS 7.

### 5.0.0 / 2017-09-12
* Removed all 'mock' support
* Bound the build to only the OS upon which you are building
* Removed legacy support code
* Designed for use within a Docker environment
  * Technically, you can install and run it inside mock but it's not
    going to do any of the heavy lifting for you any longer
* Is *NOT* backwards compatible with anything for the most part
* Ensure that published RPMs are used before rebuilding
* Cleaned up the git checking of subdirectories

### 4.1.1 / 2017-08-31
* Added the ability to read RPM release qualifier for checked out
  module from `simp-core/build/rpm/dependencies.yaml`

### 4.1.0 / 2017-08-02
* Added the ability to read from `simp-core/build/rpm/dependencies.yaml` in a
  checked out repo to add the necessary Obsoletes and Requires statements for
  external RPMs
* Changed the 'YEAR' part of the RPM release to reflect the current year
* Ensure that the 'spec/fixtures/modules' directory is no longer added to the
  RPMs

### 4.0.1 / 2017-08-02
* Reverted the bundler pinning since it was causing too many issues on CI
  systems

### 4.0.0 / 2017-07-31
* Pinned bundler to '~> 1.14.0' to allow building on FIPS-enabled systems
* Updated to simp-rspec-puppet-facts 2.0.0

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

