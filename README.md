# simp-rake-helpers

[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![Build Status](https://travis-ci.org/simp/rubygem-simp-rake-helpers.svg?branch=master)](https://travis-ci.org/simp/rubygem-simp-rake-helpers)
[![Gem](https://img.shields.io/gem/v/simp-rake-helpers.svg)](https://rubygems.org/gems/simp-rake-helpers)
[![Gem_Downloads](https://img.shields.io/gem/dt/simp-rake-helpers.svg)](https://rubygems.org/gems/simp-rake-helpers)

#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
  * [This gem is part of SIMP](#this-gem-is-part-of-simp)
  * [Features](#features)
* [Setup](#setup)
  * [Gemfile](#gemfile)
* [Usage](#usage)
  * [In a Puppet module](#in-a-puppet-module)
  * [In a Ruby Gem](#in-a-ruby-gem)
  * [Generating RPMs](#generating-rpms)
    * [RPM Changelog](#rpm-changelog)
    * [RPM Dependencies](#rpm-dependencies)
* [Reference](#reference)
  * [simp/rake/rpm](#simprakerpm)
    * [`rake pkg:rpm`](#rake-pkgrpm)
    * [`rake pkg:tar`](#rake-pkgtar)
* [Limitations](#limitations)
  * [Some versions of bundler fail on FIPS-enabled Systems](#some-versions-of-bundler-fail-on-fips-enabled-systems)
* [Development](#development)
  * [License](#license)
  * [History](#history)

<!-- vim-markdown-toc -->

## Overview

The `simp-rake-helpers` gem provides common Rake tasks to support the SIMP build process.

### This gem is part of SIMP

This gem is part of (the build tooling for) the [System Integrity Management Platform](https://github.com/NationalSecurityAgency/SIMP), a compliance-management framework built on [Puppet](https://puppetlabs.com/).


### Features

* Customizable RPM packaging based on a Puppet module's [`metadata.json`][metadata.json]
* RPM signing
* Rubygem packaging

## Setup

### Gemfile

```ruby
# Variables:
#
# SIMP_GEM_SERVERS | a space/comma delimited list of rubygem servers
# PUPPET_VERSION   | specifies the version of the puppet gem to load
puppetversion = ENV.key?('PUPPET_VERSION') ? "#{ENV['PUPPET_VERSION']}" : '~>3'
gem_sources   = ENV.key?('SIMP_GEM_SERVERS') ? ENV['SIMP_GEM_SERVERS'].split(/[, ]+/) : ['https://rubygems.org']

gem_sources.each { |gem_source| source gem_source }

group :test do
  gem 'puppet', puppetversion
  gem 'beaker-rspec'
  gem 'vagrant-wrapper'

  # Puppet 4+ has issues with Hiera 3.1+
   if puppetversion.to_s =~ />(\d+)/
     pversion = $1
     else
     pversion = puppetversion
   end

   if Gem::Dependency.new('puppet', '~> 4.0').match?('puppet', pversion)
     gem 'hiera', '~> 3.0.0'
   end

  # simp-rake-helpers does not suport puppet 2.7.X
  if "#{ENV['PUPPET_VERSION']}".scan(/\d+/).first != '2' &&
      # simp-rake-helpers and ruby 1.8.7 bomb Travis tests
      # TODO: fix upstream deps (parallel in simp-rake-helpers)
      RUBY_VERSION.sub(/\.\d+$/,'') != '1.8'
    gem 'simp-rake-helpers'
  end
end
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

### Generating RPMs

The task [`rake pkg:rpm`](#simprakerpm)) provides the ability to package an RPM
from *any* Puppet module (regardless of whether it is a SIMP module or not).
The only requirement is that the Puppet module MUST include a valid
[`metadata.json`][metadata.json] file with entries for `name`,
`version`, `license`, `summary`, and `source`.

[metadata.json]: https://docs.puppet.com/puppet/latest/reference/modules_metadata.html

The RPM package may be configured by other (optional) files under the project
directory .  The full list of files considered are:

```
./
├── metadata.json     # REQUIRED keys: name, version, license, summary, source
├── CHANGELOG         # OPTIONAL written in RPM's CHANGELOG format
└── build/            # OPTIONAL
    └── rpm_metadata/ # OPTIONAL
        ├── release   # OPTIONAL defines the RPM's "-0" release number
        ├── requires  # OPTIONAL supplementary 'Requires','Provides','Obsoletes'
        └── custom/   # OPTIONAL
          └── *       # OPTIONAL custom snippets in RPM .spec format
```

*NOTE*: The dependencies in `metadata.json` are *not* used to generate RPM
dependencies!


#### RPM Changelog

The RPM Changelog will be derived from a `CHANGELOG` file at the top
level of the project, if it exists.

  * The file is expected to conform to the [RPM Changelog][RPM CHANGELOG]
    format described in the Fedora packaging guidelines
  * The file MUST start with a well-formatted RPM changelog string, or it will
    be ignored.
  * The format is *not* fully checked before attempting to build the RPM―the
    RPM build will fail if the Changelog entries are not valid.

[RPM CHANGELOG]: https://fedoraproject.org/wiki/Packaging:Guidelines#Changelogs


#### RPM Dependencies

It is likely that you will want to declare your dependencies in your RPM. To do
this, create a `build/rpm_metadata` directory at the root of the project.
A `requires` file in the `build/rpm_metadata` directory will be
used to declare the dependencies of the RPM. A file named `release` in the
`build/rpm_metadata` directory will be used to declare the RPM release
number.

The following directives may be declared in the `requires` file:
  * `Provides:`
  * `Requires:`
  * `Obsoletes:`

## Reference

### simp/rake/rpm

#### `rake pkg:rpm`

Packages the current SIMP project as an RPM

#### `rake pkg:tar`

Build the tar package for the current SIMP project

## Limitations

### Some versions of bundler fail on FIPS-enabled Systems

This is a limitation of Bundler, not the gem.

If you are running on a FIPS-enabled system, you will need to use `bundler '~> 1.14.0'`
until the FIPS support can be corrected.

If you are using RVM, the appropriate steps are as follows:

```shell
rm Gemfile.lock ||:
rvm @global do gem uninstall bundler -a -x
rvm @global do gem install bundler -v '~> 1.14.0'
```

## Development

Please see the [SIMP Contribution Guidelines](https://simp-project.atlassian.net/wiki/display/SD/Contributing+to+SIMP).

### License

See [LICENSE](LICENSE)

### History

See [CHANGELOG.md](CHANGELOG.md)
