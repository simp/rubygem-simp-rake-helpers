# simp-rake-helpers
[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/rubygems-simp-rake-helpers.svg?branch=master)](https://travis-ci.org/simp/rubygems-simp-rake-helpers)

#### Table of Contents

1. [Overview](#overview)
  * [This gem is part of SIMP](#this-gem-is-part-of-simp)
  * [Features](#features)
2. [Setup - The basics of getting started with iptables](#setup)
3. [Usage - Configuration options and additional functionality](#usage)
  * [In a Puppet Module](#in-a-puppet-module)
  * [In a Ruby Gem](#in-a-ruby-gem)
4. [Reference - An under-the-hood peek at what the gem is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
  * [License](#license)
  * [History](#history)


## Overview
The `simp-rake-helpers` gem provides common Rake tasks to support the SIMP build process.


### This gem is part of SIMP
This gem is part of (the build tooling for) the [System Integrity Management Platform](https://github.com/NationalSecurityAgency/SIMP), a compliance-management framework built on [Puppet](https://puppetlabs.com/).


### Features
* supports multithreaded mock operations
* RPM packaging and signing


## Setup
Within a project's Gemfile:

```ruby
gem 'simp-rake-helpers'
```


## Usage
### In a Puppet module
Within the project's Rakefile:

```ruby
require 'simp/rake/pupmod/helpers'

Simp::Rake::Pupmod::Helpers.new(File.dirname(__FILE__))
```



### In a Ruby Gem
Within the project's Rakefile:

```ruby
require 'simp/rake/rubygem'

# e.g., "simp-rake-helpers"
package = 'name-of-rubygem'
Simp::Rake::Rubygem.new(package, File.direname(__FILE__)

```

To see the extra rake tasks:

```sh
bunde exec rake -T
```

## Reference

### simp/rake/rpm

#### rake pkg:rpm[chroot,unique,snapshot_release]
Builds an RPM to package the current SIMP project.

**NOTE**: Building RPMs requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)

##### Parameters

  * **:chroot** - The Mock chroot configuration to use. See the '--root' option in mock(1)."
  * **:unique** - Whether or not to build the RPM in a unique Mock environment.  This can be very useful for parallel builds of all modules.
* **:snapshot_release** - Add snapshot_release (date and time) to rpm version.  Rpm spec file must have macro for this to work.


#### rake pkg:scrub[chroot,unique]

Scrub the current SIMP project's mock build directory.


#### rake pkg:srpm[chroot,unique,snapshot_release]
Build the pupmod-simp-iptables SRPM.   Building RPMs requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)

**NOTE**: Building RPMs requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)

##### Parameters

  * **:chroot** - The Mock chroot configuration to use. See the '--root' option in mock(1)."
  * **:unique** - Whether or not to build the SRPM in a unique Mock environment.  This can be very useful for parallel builds of all modules.
  * **:snapshot_release** - Add snapshot_release (date and time) to rpm version.  The RPM spec file must support macros for this to work.

#### rake pkg:tar[snapshot_release]

##### Parameters

Build the pupmod-simp-iptables tar package
  * :snapshot_release - Add snapshot_release (date and time) to rpm version, rpm spec file must have macro for this to work.

## Limitations


## Development

Please see the [SIMP Contribution Guidelines](https://simp-project.atlassian.net/wiki/display/SD/Contributing+to+SIMP).

### License
See [LICENSE](LICENSE)


### History
See [CHANGELOG.md](CHANGELOG.md)
