require 'date'
require 'simp/componentinfo'
require 'simp/rpm/specfileinfo'
require 'tmpdir'

module Simp; end

# Class that provide release-related checks
class Simp::RelChecks

  CHECK_RPM_CHANGELOG_DESCRIPTION = <<-EOM
  Check a component's RPM changelog using the 'rpm' command.

  This task will fail if 'rpm' detects any changelog problems,
  such as changelog entries not being in reverse chronological
  order.
  EOM
  #
  # +component_dir+:: The root directory of the component project.
  # +simp_version+::  Version of SIMP.  Used to select the LUA-based,
  #                   RPM spec file template, when the project does
  #                   not contain a spec file in <base_dir>/build.
  # +verbose+::       Set to 'true' if you want to see details about the
  #                   RPM command executed.
  def self.check_rpm_changelog(component_dir, simp_version=nil, verbose = false)
    begin
      info = nil
      local_specs = Dir.glob(File.join(component_dir, 'build', '*.spec'))
      unless local_specs.empty?
        spec_file = local_specs.first
        if local_specs.size > 1
         $stderr.puts "WARNING:  Multiple spec files found for #{component_dir}.  Using #{spec_file}"
        end
        info = Simp::Rpm::SpecFileInfo.new(spec_file, [], verbose)
      else
        info = Simp::Rpm::TemplateSpecFileInfo.new(component_dir, simp_version, [], verbose)
      end
      info.changelog
    rescue Simp::Rpm::QueryError => e
      err_msg =  "ERROR: Invalid changelog for #{File.basename(component_dir)}:\n"
      err_msg +=  e.message
      fail(err_msg)
    end
  end

  COMPARE_LATEST_TAG_DESCRIPTION = <<-EOM
  Compares mission-impacting (significant) files with the latest
  tag and identifies the relevant files that have changed.

  Fails if
  (1) There is any version validation or changelog parsing failure
      that would prevent a changelog for an annotated tag from being
      created.
  (2) A version bump is required but not recorded in both the
      CHANGELOG and metadata.json files.
  (3) The latest version is < latest tag.

  Changes to the following files/directories are not considered
  significant:
  - Any hidden file/directory (entry that begins with a '.')
  - Gemfile
  - Gemfile.lock
  - Rakefile
  - spec directory
  - doc directory
  EOM
  # @see Simp::RelCheck::create_tag_changelog
  #
  # +component_dir+:: The root directory of the component project.
  # +tags_source+::   The remote from which the tags for this project
  #                   can be fetched.
  # +verbose+::       Set to 'true' if you want to see detailed messages
  def self.compare_latest_tag(component_dir, tags_source = 'origin', verbose = false)
    info, _ = load_and_validate_changelog(component_dir, verbose)
    Dir.chdir(component_dir) do
      # determine last tag
      `git fetch -t #{tags_source} 2>/dev/null`
      tags = `git tag -l`.split("\n")
      puts "Available tags from #{tags_source} = #{tags}" if verbose
      tags.delete_if { |tag| tag.include?('-') or (tag =~ /^v/) }

      if tags.empty?
        puts "  No tags exist from #{tags_source}"
      else
        last_tag = (tags.sort { |a,b| Gem::Version.new(a) <=> Gem::Version.new(b) })[-1]

        # determine mission-impacting files that have changed
        files_changed = `git diff tags/#{last_tag} --name-only`.strip.split("\n")
        files_changed.delete_if do |file|
          file[0] ==  '.' or file == 'Rakefile' or file =~ /^Gemfile|^spec\/|^doc\//
        end

        if files_changed.empty?
          puts "  No new tag required: No significant files have changed since '#{last_tag}' tag"
        else
          curr_version = Gem::Version.new(info.version)
          last_tag_version = Gem::Version.new(last_tag)

          if curr_version < last_tag_version
            fail("ERROR: Version regression. '#{info.version}' < last tag '#{last_tag}'")
          elsif curr_version == last_tag_version
            fail("ERROR: Version update beyond last tag '#{last_tag}' is required for #{files_changed.count} changed files:\n  * #{files_changed.join("\n  * ")}")
          else
            puts "NOTICE: New tag of version '#{info.version}' is required for #{files_changed.count} changed files:\n  * #{files_changed.join("\n  * ")}"
          end
        end
      end
    end
  end

  CREATE_TAG_CHANGELOG_DESCRIPTION = <<-EOM
  Generate an appropriate changelog for an annotated tag from
  a component's CHANGELOG or RPM spec file.

  The changelog text will be for the latest version and contain
  1 or more changelog entries for that version, in reverse
  chronological order. However, the changelog is only parsed up
  to the first entry that fails validation.

  NOTES:
    * Changelog entries must follow the following rules:
      - An entry must start with * and be terminated by a blank line.
      - The first line must be of the form
          * Wed Jul 05 2017 Author Name <author@simp.com> - 1.2.3-4
      - The date string must be RPM compatible.
      - Dates must be in reverse chronological order, with the
        newest dates occurring at the top of the changelog.
      - Both an author name and email are required.
      - The author email must be contained in < >.
      - The version is required and must be of the form
              <major>.<minor>.<patch>.
      - The version may contain a release qualifier.
      - When the release qualifier is present, it must appear
        at the end of the version string and be separated from
        the version by a '-'.

    * Fails if any of the following occur:
      - The metadata.json file for a Puppet module component cannot be parsed.
      - The CHANGELOG file for a Puppet module component does not exist.
      - The CHANGELOG file begins with a blank line.
      - The CHANGELOG entries for the latest version are malformed.
      - The RPM spec file or a non-Puppet module component does not exist.
      - More than 1 RPM spec file for a non-Puppet module component exists.
      - No valid changelog entries for the version specified in
        the metadata.json/spec file are found.
      - The latest changelog version is greater than the version
        in the metadata.json or the RPM spec file.
      - The RPM release specified in the spec file does not match
        the release in a changelog entry for the version.
      - Any changelog entry below the first entry has a version
        greater than that of the first entry.
      - The changelog entries for all versions are out of date order.
      - The weekday for a changelog entry for the latest version
        does not match the date specified.
  EOM
  #
  # +component_dir+:: The root directory of the component project.
  # +verbose+:: Whether to log non-catestrophic changelog parsing
  #   failures.
  def self.create_tag_changelog(component_dir, verbose = false)
    info, changelogs = load_and_validate_changelog(component_dir,verbose)

    result = "\nRelease of #{info.version}\n"
    changelogs.each do |entry|
      result += "\n#{entry[:content].first}\n"
      if entry[:content].size > 1
        entry[:content][1..-1].each do |line|
          result += "  #{line}\n"
        end
      end
    end
    result
  end

  # Returns all changelog entries for the version
  #
  # Fails if
  # - No valid entries for specified version are found
  # - The latest changelog version is greater than the specified version
  # - The release qualifier in a changelog entry for the specified
  #   version does not match the specified release.
  #
  # +changelog_entries+:: Array containing valid changelog entries, each of
  #   which is a Hash with :date, :version, :release, and :content keys
  #
  # +version+:: Target version for which one or more changelog entries
  #   are to be extracted
  #
  # +release+:: Optional release qualifier for version
  # +verbose+:: Whether to log non-catestrophic changelog parsing
  #   failures.
  def self.extract_version_changelog(changelog_entries, version,
      release=nil, verbose=false)

    changelogs = []
    changelog_entries.each do |entry|
      if entry[:version] > version
          fail("ERROR: Changelog entry for version > #{version} found: \n #{entry[:content].join("\n")}")
        elsif entry[:version] < version
          break
        elsif entry[:version] == version
          # If release is extracted from an RPM spec file, it may have
          # a distribution at the end (e.g., 0.el7).  We can't extract
          # distribution from a specfile (query returns 'none' for
          # DISTRIBUTION and DISTAG tags), so make sure the beginning
          # of the release matches.
          if release and entry[:release] and release.match(/^#{entry[:release]}/).nil?
            fail("ERROR: Version release does not match #{release}: \n #{entry[:content].join("\n")}")
          end
          changelogs << entry
      end
    end

    if changelogs.empty?
      fail("ERROR: No valid changelog entry for version #{version} found")
    end
    changelogs
  end

  def self.load_and_validate_changelog(component_dir, verbose)
    # only get valid changelog entries for the latest version
    # (up to the first malformed entry)
    info = Simp::ComponentInfo.new(component_dir, true, verbose)

    changelogs = extract_version_changelog(info.changelog, info.version,
        info.release, verbose)

    [info, changelogs]
  end
end
