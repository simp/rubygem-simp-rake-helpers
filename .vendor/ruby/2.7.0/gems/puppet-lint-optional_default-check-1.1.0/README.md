puppet-lint-optional\_default-check
===================================

[![License](https://img.shields.io/github/license/voxpupuli/puppet-lint-optional_default-check.svg)](https://github.com/voxpupuli/puppet-lint-optional_default-check/blob/master/LICENSE)
[![Test](https://github.com/voxpupuli/puppet-lint-optional_default-check/actions/workflows/test.yml/badge.svg)](https://github.com/voxpupuli/puppet-lint-optional_default-check/actions/workflows/test.yml)
[![Release](https://github.com/voxpupuli/puppet-lint-optional_default-check/actions/workflows/release.yml/badge.svg)](https://github.com/voxpupuli/puppet-lint-optional_default-check/actions/workflows/release.yml)
[![RubyGem Version](https://img.shields.io/gem/v/puppet-lint-optional_default-check.svg)](https://rubygems.org/gems/puppet-lint-optional_default-check)
[![RubyGem Downloads](https://img.shields.io/gem/dt/puppet-lint-optional_default-check.svg)](https://rubygems.org/gems/puppet-lint-optional_default-check)
[![Donated by Alexander Fisher](https://img.shields.io/badge/donated%20by-Alexander%20Fisher-fb7047.svg)](#transfer-notice)


A puppet-lint plugin to check that `Optional` parameters don't default to something other than `undef`.

## Table of contents

* [Installing](#installing)
  * [From the command line](#from-the-command-line)
  * [In a Gemfile](#in-a-gemfile)
* [Checks](#checks)
* [Copyright](#copyright)
* [Transfer notice](#transfer-notice)
* [License](#license)
* [Release Informaion](#release-information)

## Installing

### From the command line

```shell
$ gem install puppet-lint-optional_default-check
```

### In a Gemfile

```ruby
gem 'puppet-lint-optional_default-check', :require => false
```

## Checks

### `Optional` parameter defaults to something other than `undef`

An `Optional` parameter in Puppet is one where `undef` is an allowed value.

It is normally a mistake to set the default of an `Optional` parameter to something other than `undef`.
This is because it's not possible to 'pass' `undef` as the value to use for a parameter when declaring a class or defined type.
When you try to set a parameter to `undef`, Puppet actually uses the class's default value for that parameter, not `undef` itself.

(The caveat is that it is possible to use hiera to override a non `undef` default back to `undef`, but in practice, doing this is quite rare.)

A **defined type** with an mandatory (no default), `Optional` parameter will raise a warning.

The plugin will not raise a warning if a **class** `Optional` parameter doesn't have a default.
Mandatory parameters can have defaults set in hiera, and several modules *do* use `~` for this.

#### What you have done

```puppet
class foo (
  Optional[Integer] $port = 8080,
){
}
```

#### What you should have done

```puppet
class foo (
  Integer $port = 8080,
){
}
```

or

```puppet
class foo (
  Optional[Integer] $port = undef,
){
}
```

## Copyright

Copyright 2021 Alexander Fisher

## Transfer Notice

This plugin was originally authored by [Alexander Fisher](https://github.com/alexjfisher).
The maintainer preferred that [Vox Pupuli](https://voxpupuli.org/) take ownership of the module for future improvement and maintenance.
Existing pull requests and issues were transferred, please fork and continue to contribute [here](https://github.com/voxpupuli/puppet-lint-optional_default-check) instead of on Alex's [fork](https://github.com/alexjfisher/puppet-lint-optional_default-check).

## License

This gem is licensed under the MIT license.

## Release information

To make a new release, please do:
* Update the version in the `puppet-lint-optional_default-check.gemspec` file
* Install gems with `bundle install --with release --path .vendor`
* generate the changelog with `bundle exec rake changelog`
* Create a PR with it
* After it got merged, push a tag. A github workflow will do the actual release
