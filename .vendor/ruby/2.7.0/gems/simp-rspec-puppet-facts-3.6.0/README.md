# simp-rspec-puppet-facts

[![Build Status](https://img.shields.io/travis/simp/simp-rspec-puppet-facts/master.svg)](https://travis-ci.org/simp/simp-rspec-puppet-facts)
[![Gem Version](https://img.shields.io/gem/v/simp-rspec-puppet-facts.svg)](https://rubygems.org/gems/simp-rspec-puppet-facts)

Simplify your spec tests by looping on every supported Operating System and populating facts.

* [Motivation](#motivation)
* [Usage](#usage)
	* [Basic usage](#basic-usage)
	* [Providing options](#providing-options)
* [Options](#options)
	* [`:extra_facts`](#extra_facts)
	* [`:extra_facts_immutable`](#extra_facts_immutable)
	* [`:selinux_mode`](#selinux_mode)
		* [Example: Default SELinux mode (`:enforcing`)](#example-default-selinux-mode-enforcing)
		* [Example: Setting facts to model when SELinux is `disabled`](#example-setting-facts-to-model-when-selinux-is-disabled)
* [Environment Variables](#environment-variables)
	* [`SIMP_FACTS_OS`](#simp_facts_os)
	* [`SIMP_FACTS_lsb`](#simp_facts_lsb)
* [How to capture new facts](#how-to-capture-new-facts)

## Motivation
The `on_supported_os` method provided by rspec-puppet-facts provides facts captured from running Vagrant systems.  However, many SIMP tests require additional custom facts.

This gem acts as a shim in front of [mcanevet/rspec-puppet-facts](https://github.com/mcanevet/rspec-puppet-facts) and can be used as a drop-in replacement when testing for SIMP.  It uses a combination of Vagrant-captured SIMP facts and logic to model certain environments (e.g., SELinux modes, LSB facts being present or not).

## Usage

### Basic usage

Use this code inside `spec_helper.rb`:
```ruby
require 'simp/rspec-puppet-facts'
include Simp::RspecPuppetFacts
```

Use this structure inside your `*_spec.rb` files:
```ruby
require 'spec_helper'

describe 'module_name::class_name' do
  # loops through and provides facts for each supported os in metadata.json
  on_supported_os.each do |os, base_facts|
    context "on #{os}" do
      let(:facts){ base_facts.dup }
      it { is_expected.to compile.with_all_deps }
    end
  end
end
```

### Providing options
See the [options](#options) for details
```ruby
  on_supported_os({:extra_facts=>{:username=>'flastname'}})
  on_supported_os({:selinux_mode=>:permissive})
```


## Options

### `:extra_facts`

_[default: {}]_

Override or add extra facts to each os/facts hash.

**NOTE:**  Facts managed by internal logic (such as `:selinux`, `:selinux_current_mode`, `:tmp_mount_*`, etc) will still be overwritten.  To avoid this, use `:extra_facts_immutable` instead.


### `:extra_facts_immutable`

_[default: {}]_

Override or add extra facts to each os/facts hash.  These facts cannot be altered by internal logic (such as `:selinux_mode`).



### `:selinux_mode`

_[default: **`:enforcing`**]_

Given an enforcement mode (`:enforcing`, `:permissive`, or `:disabled`), overrides the following facts:
  - `selinux`
  - `selinux_enforced`
  - `selinux_current_mode`
  - `selinux_state`
  - `tmp_mount_*` _(only modifies existing `tmp_mount*` facts)_

#### Example: Default SELinux mode (`:enforcing`)

```ruby
# Default facts (`.first.last` returns facts for the first os)
facts_hash = on_supported_os.first.last
facts_hash.values_at(:selinux,:selinux_current_mode,:selinux_state,:tmp_mount_dev_shm)
### => [true, "enforcing", "enforcing", "rw,relatime,seclabel"]
```


#### Example: Setting facts to model when SELinux is `disabled`

```ruby
# Set selinux mode to `disabled`
facts_hash = on_supported_os({:selinux_mode => :disabled}).first.last
facts_hash.values_at(:selinux,:selinux_current_mode,:selinux_state,:tmp_mount_dev_shm)
### => [false, "disabled", "disabled", "rw,relatime"]
```

## Environment Variables

### `FACTER_GEM_VERSION`

Set to install a specific version of `facter`. Only works on systems where
`puppet` can be installed natively via `gem`.

### `BEAKER_facter_ng`

Set to `yes` to switch over to using `facter-ng` (Facter 4) for collection.

Requires using `beaker` to collect facts.

### `SIMP_FACTS_OS`

Restricts test matrix to OS strings/partial strings/regexps provided in a
comma-delimited list.

- **Example:** `SIMP_FACTS_OS=redhat-7-x86_64,centos`


### `SIMP_FACTS_lsb`

Mock the output of historical lsb facts

- Disable by setting to `no`


## How to capture new facts

### Beaker (preferred)

- Add nodesets to `spec/acceptance/nodesets`
- Run `bundle exec rake beaker:suites[default,ALL]`
  - Replace `ALL` with the name of a specific nodeset if you only want to
    collect on a single OS.
- Review the facts in the `collected_facts` directory.
- Update the facts in the associated `facts` directory.
  - Make sure to rename the file as `<lowercase_os>-<major_version>-<arch>`

### Vagrant

- Place any modules containing facts you want to capture under `modules/`
- Run `vagrant up`
**NOTE:** This replaces any older fact data

