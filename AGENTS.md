# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What This Gem Does

`simp-rake-helpers` provides shared Rake tasks used across all SIMP Puppet modules and related gems. It is consumed via `require 'simp/rake/pupmod/helpers'` (or similar) in the Rakefiles of other repos — it is not a standalone application.

## Common Commands

```bash
bundle install                          # Install dependencies
bundle exec rake spec                   # Run all unit tests (RSpec)
bundle exec rspec spec/lib/simp/rpm_spec.rb          # Run a single spec file
bundle exec rspec spec/lib/simp/rpm_spec.rb -e 'name' # Run a single example by name
bundle exec rake acceptance             # Run acceptance tests (Beaker)
bundle exec rake pkg:gem                # Build the .gem package
bundle exec rake pkg:install_gem        # Build and install gem locally
bundle exec rake -T                     # List all available tasks
```

RSpec is configured in `.rspec` (documentation format, color, fail-fast on first failure).

## Architecture

### Task-Defining Classes (inherit from `Rake::TaskLib`)

Each class takes a base directory and defines a task namespace via a `define` method.

| Class | File | Tasks Defined |
|-------|------|---------------|
| `Simp::Rake::Pupmod::Helpers` | `lib/simp/rake/pupmod/helpers.rb` | Full Puppet module task suite: spec, lint, pkg, acceptance |
| `Simp::Rake::Pkg` | `lib/simp/rake/pkg.rb` | `pkg:tar`, `pkg:rpm`, `pkg:check_rpm_changelog` — RPM/tarball packaging from `metadata.json` |
| `Simp::Rake::Rubygem` | `lib/simp/rake/rubygem.rb` | `pkg:gem`, `pkg:install_gem`, `spec`, `acceptance` — used by this gem itself |
| `Simp::Rake::Fixtures` | `lib/simp/rake/fixtures.rb` | `fixtures:generate`, `fixtures:diff` — `.fixtures.yml` from Puppetfiles |
| `Simp::Rake::Ci` | `lib/simp/rake/ci.rb` | `simp:ci_lint`, `simp:gitlab_ci_lint` |
| `Simp::Rake::Build::*` | `lib/simp/rake/build/` | Full SIMP ISO/distribution build tasks (12+ submodules: auto, deps, iso, tar, pkg, etc.) |

### Core Utility Classes

| Class | File | Purpose |
|-------|------|---------|
| `Simp::RPM` | `lib/simp/rpm.rb` | Parse RPM metadata from spec files and built RPMs; detect system dist tag |
| `Simp::ComponentInfo` | `lib/simp/componentinfo.rb` | Extract version/release from `metadata.json` or spec; validate CHANGELOG format |
| `Simp::RelChecks` | `lib/simp/relchecks.rb` | Release validation: changelog format, version ordering, tag comparison |
| `Simp::Ci::Gitlab` | `lib/simp/ci/gitlab.rb` | Validate `.gitlab-ci.yml` acceptance job configs against available suites/nodesets |
| `Simp::RpmSigner` | `lib/simp/rpm_signer.rb` | GPG signing of RPMs; key management |
| `Simp::CommandUtils` | `lib/simp/command_utils.rb` | Facter-based command availability checking with caching |

### RPM Spec Generation

`pkg:rpm` auto-generates an RPM spec from a template (`lib/simp/rake/helpers/rpm_spec.rb`) using `metadata.json` as the source of truth for version, description, and dependencies. Modules can override via `build/rpm_metadata/` (requires, release info, custom spec snippets).

### Fixture Management

`Simp::Rake::Fixtures` can generate `.fixtures.yml` from a Puppetfile (local or remote URL) instead of the checked-in file. Key environment variables:

- `SIMP_RSPEC_PUPPETFILE` — use a Puppetfile instead of `.fixtures.yml`
- `SIMP_RSPEC_MODULEPATH` — symlink modules from a local path
- `SIMP_RSPEC_FIXTURES_OVERRIDE` — override local fixtures.yml entirely

### Other Notable Environment Variables

- `PUPPET_VERSION` — pin Puppet gem version
- `SIMP_GEM_SERVERS` — space/comma-separated gem server URLs
- `SIMP_RAKE_LIMIT_CPUS` — limit parallel build workers
- `SIMP_RAKE_MOCK_OFFLINE` — offline mock builds
- `SIMP_RPM_dist` — force a specific RPM dist tag (e.g. `el8`)
