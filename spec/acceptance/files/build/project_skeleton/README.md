# Dummy super-release (`simp-core`) project

The contents of this directory tree provide _just enough _directories and dummy
files for a `rake -T` to avoid failing during ` Simp::Rake::Build::Helpers.new`

## What this provides

* A (paper-thin) dummy for a super-release project like [`simp-core`][simp-core])
* A means to acceptance-test `simp/rake/build/helpers`

## How to use this project in your acceptance tests

To use this project in your acceptance tests:

* `rsync` this directory tree into a test-specific directory root
* copy in any specific assets you need for your tests
* run `bundle exec rake <task>` to test the scenario you have modeled.
