require 'date'
require 'simp/componentinfo'
require 'tmpdir'

module Simp; end

# Class that provide release-related checks
class Simp::RelChecks

  # Check a component's RPM changelog using the 'rpm' command.
  #
  # This task will fail if 'rpm' detects any changelog problems,
  # such as changelog entries not being in reverse chronological
  # order.
  #
  # +component_dir+:: The root directory of the component project.
  # +spec_file+::     The RPM specfile for the component.
  # +verbose+::       Set to 'true' if you want to see details about the
  #                   RPM command executed.
  def self.check_rpm_changelog(component_dir, spec_file, verbose = false)
    rpm_opts = [
      # for modules, '_sourcedir' tells the RPM LUA code the location
      # of the CHANGELOG and metadata.json files
      %(-D '_sourcedir #{component_dir}'),
      '-q',
      '--changelog',
      "--specfile  #{spec_file}"
    ]
    rpm_opts << '-v' if verbose

    cmd = %(rpm #{rpm_opts.join(' ')} 2>&1)
    puts "==== Simp::RelChecks::check_rpm_changelog: #{cmd}" if verbose
    console = %x(#{cmd})
    result = $?
    if result
      if result.exitstatus != 0
        err_msg = [ "ERROR: Invalid changelog for #{File.basename(component_dir)}:\n" ]
        err_msg << console.split("\n").map { |line| "   #{line}" }
        err_msg << "\n"
        fail(err_msg.flatten.join("\n"))
      end
    else
      # Ruby can return nil for spawned shells, sigh
      fail("Unable to determine changelog for #{File.basename(component_dir)}")
    end
  end

  # Compares mission-impacting (significant) files with the latest
  # tag and identifies the relevant files that have changed.
  #
  # Fails if
  # (1) There is any version validation or changelog parsing failure
  #     that would prevent an annotated changelog tag from being
  #     created. (See Simp::RelCheck::create_tag_changelog)
  # (2) A version bump is required but not recorded in both the
  #     CHANGELOG and metadata.json files.
  # (3) The latest version is < latest tag.

  # Changes to the following files/directories are not considered
  # significant:
  # - Any hidden file/directory (entry that begins with a '.')
  # - Gemfile
  # - Gemfile.lock
  # - Rakefile
  # - rakelib directory
  # - spec directory
  # - doc directory
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
          file[0] ==  '.' or file == 'Rakefile' or file =~ /^Gemfile|^spec\/|^doc\/|^rakelib\/|.*\.md\Z/
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

  # Generate an appropriate changelog for an annotated tag from a
  # component's CHANGELOG or RPM spec file.
  #
  # The changelog is only parsed up to the first entry that fails
  # validation.
  #
  # Fails if any of the following occur:
  # - The metadata.json file for a Puppet module component cannot be
  #   parsed.
  # - The CHANGELOG file for a Puppet module component does not exist.
  # - The CHANGELOG entries for the latest version are malformed.
  # - The RPM spec file for a non-Puppet module component does not exist.
  # - More than 1 RPM spec file for a non-Puppet module component exists.
  # - No valid changelog entries for the version specified in the
  #   metadata.json/spec file are found.
  # - The latest changelog version is greater than the version in the
  #   metadata.json or the RPM spec file.
  # - The RPM release specified in the spec file does not match the
  #   release in a changelog entry for the version.
  # - Any changelog entry below the first entry has a version greater
  #   than that of the first entry.  Changelog entries must be
  #   ordered from latest version to earliest version.
  # - The changelog entries for the latest version are out of date
  #   order.
  # - The weekday for a changelog entry for the latest version
  #   does not match the date specified.
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
