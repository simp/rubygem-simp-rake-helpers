require 'date'

module Simp; end

# Class that provides component version, release, and changelog
# information
class Simp::ComponentInfo
  attr_accessor :component_dir, :type, :version, :release, :changelog

  # A helpful method for ensuring that the errors can be easily seen
  ERR_MARKER = "WARNING: !!! "

  # See https://fedoraproject.org/wiki/Packaging:Guidelines?rd=Packaging/Guidelines#Changelogs
  # When matched against this regex
  #   match 1 = date of the form {weekday} {month} {day} {year}
  #   match 2 = author of the form {name} <{email}>
  #   match 3 = version
  #   match 4 = optional release qualifier; nil when absent
  CHANGELOG_ENTRY_REGEX = /^\*\s+((?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [0-3]{1}[0-9]{1} \d{4})\s+(.+<.+>)(?:\s+|\s*-\s*)(\d+\.\d+\.\d+)(?:-(\S+))?\s*$/

  # Load component information from appropriate component files
  #
  # Module
  #   version:     Top-level 'version' key from the metadata.json file
  #   release:     Not set
  #   changelog:   Array of valid changelog entries derived from the
  #                CHANGELOG file
  #
  # Asset
  #   version:     Primary Version tag from build/<component>.spec
  #   release:     Primary Release tag from build/<component>.spec
  #   changelog:   Array of valid changelog entries derived from the
  #                contents of the %changelog section in
  #                build/<component>.spec.  Will be an empty if
  #                %changelog is not present.
  #
  #  NOTES:
  #  1.  The changelog is only parsed up to the first entry that
  #      fails basic validation.
  #      - First line must be of the form
  #         * {date string} {author info} - {version}
  #         * {date string} {author info} - {version}-{release}
  #
  #        where,
  #         date string =  {weekday} {month} {day} {year}
  #         author info =  {author name} <{author email}>
  #      - Weekday must be correct for the specified date
  #      - Entries must be separated by a blank line
  #
  #      NOTE: This currently does not support the valid RPM `%changelog`
  #       format that places the version number on the next line:
  #
  #       * Fri Mar 02 2012 Maintenance
  #       4.0.0-2
  #       - Improved test stubs.
  #
  #       However, since we are not using this form for recent
  #       changelogs and we stop processing upon reaching such
  #       a changelog entry, this should *not* be an issue.
  #  2.  When RPM spec files contain sub-packages, only the primary
  #      package information is returned.
  #  3.  Some assets have another version in a lib/.../version.rb.
  #      Since there is no definitive way for this code to determine
  #      that version, it will not be loaded here.
  #
  # Fails if any of the following occur:
  # - The metadata.json file for a Puppet module component cannot be
  #   parsed.
  # - A top-level 'version' key does not exist in the metadata.json file.
  # - The CHANGELOG file for a Puppet module component does not exist.
  # - The RPM spec file for a non-Puppet module component does not exist.
  # - More than 1 RPM spec file for a non-Puppet module component exists.
  # - The version, release or changelog cannot be extracted from the RPM
  #   spec file for a non-Puppet module.
  #  - Any changelog entry below the first entry has a version greater
  #   than that of the first entry.  Changelog entries must be
  #   ordered from latest version to earliest version.
  # - The changelog entries are out of date order.
  #
  # +component_dir+:: The root directory of the component project.
  # +latest_version_only+:: Whether to only return the changelog
  #  entries for  the latest version
  # +verbose+:: Whether to log a changelog validation failure
  #
  def initialize(component_dir, latest_version_only = false, verbose = true)
    @component_dir = component_dir

    if File.exist?(File.join(@component_dir, 'metadata.json'))
      @type = :module
      load_module_info(latest_version_only, verbose)
    else
      @type = :asset
      load_asset_info(latest_version_only, verbose)
    end
  end

  private
  def load_module_info(latest_version_only, verbose)
    require 'json'
    metadata_file = File.join(@component_dir, 'metadata.json')
    metadata = JSON.parse(File.read(metadata_file))
    fail("ERROR: Version missing from #{metadata_file}") if metadata['version'].nil?

    @version = metadata['version'].split('-').first
    rel_bits = metadata['version'].split('-')[1..-1]
    @release = rel_bits.empty? ? nil : rel_bits.join('-')


    changelog_file = File.join(component_dir, 'CHANGELOG')
    unless File.exist?(changelog_file)
      fail("ERROR: No CHANGELOG file found in #{component_dir}")
    end
    @changelog = parse_changelog(IO.read(changelog_file), latest_version_only, verbose)
  end

  def load_asset_info(latest_version_only, verbose)
    rpm_spec_files = Dir.glob(File.join(@component_dir, 'build', '*.spec'))
    if rpm_spec_files.empty?
      fail("No RPM spec file found in #{File.join(@component_dir, 'build')}")
    elsif rpm_spec_files.size > 1
      fail("More than 1 RPM spec file found: #{rpm_spec_files.join(' ')}")
    end

    # Determine asset version, which we will ASSUME to be the main
    # package version.  The RPM query, below, will return the main
    # package followed by subpackages.
    version_query = "rpm -q --queryformat '%{VERSION} %{RELEASE}\\n'" +
      " --specfile #{rpm_spec_files[0]}"

    rpm_version_list = `#{version_query} 2> /dev/null`
    if $?.exitstatus != 0
      fail("Could not extract version and release from #{rpm_spec_files[0]}." +
        " To debug, execute:\n   #{version_query}")
    end
    @version, @release = rpm_version_list.split("\n")[0].split

    changelog_query = "rpm -q --changelog --specfile #{rpm_spec_files[0]}"
    raw_changelog = `#{changelog_query} 2> /dev/null`
    if $?.exitstatus != 0
      fail("Could not extract changelog from #{rpm_spec_files[0]}." +
        " To debug, execute:\n   #{changelog_query}")
    elsif raw_changelog.strip.empty?
      changelog_lines = []

      in_changelog = false
      File.read(rpm_spec_files[0]).lines.each do |line|
        changelog_lines << line if in_changelog

        if line.start_with?('%')
          if line.start_with?('%changelog')
            in_changelog = true
          else
            in_changelog = false
          end
        end
      end

      raw_changelog = changelog_lines.join
    end
    @changelog = parse_changelog(raw_changelog, latest_version_only, verbose)
  end

  # Return an array of changelog entries, optionally for only the
  # latest version
  #
  # Iterates through the changelog entries from the newest to the
  # oldest, performing basic validation.  Stops processing entries
  # if an entry fails validation.
  #
  def parse_changelog(changelog, latest_version_only, verbose)
    # split on the entry-separating lines
    changelog_entries = changelog.split(/\n\n+/)
    latest_version = nil # 1st version found is latest version
    prev_entry_date = nil
    changelogs = []
    changelog_entries.each do |entry|
      # split each entry into lines, removing the initial, empty line
      # that occurs on all but the first entry
      changelog_lines = entry.split("\n").delete_if { |line| line.empty? }
      match = CHANGELOG_ENTRY_REGEX.match(changelog_lines[0])
      if match.nil?
        warn "WARNING: Parsing stopped at invalid changelog entry: \n#{entry}" if verbose
        break
      else
        # verify 1st version is latest version
        # NOTE:  There are edge cases in which comparisons between
        # versions with and without release qualifiers may give answers
        # that are not expected.  For example, '6.2.0' > '6.2.0-1'.
        full_version = match[3]
        full_version += "-#{match[4]}" unless match[4].nil?
        current_version = Gem::Version.new(full_version)
        latest_version = current_version if latest_version.nil?
        if current_version > latest_version
          fail("ERROR:  Changelog entries are not properly version ordered")
        end

        break if latest_version_only and (current_version < latest_version)

        # verify dates are appropriately ordered (newest to oldest)
        current_entry_date = Date.strptime(match[1], '%a %b %d %Y')
        prev_entry_date = current_entry_date if prev_entry_date.nil?
        if current_entry_date > prev_entry_date
          fail("ERROR:  Changelog entries are not properly date ordered")
        end

        if valid_date_weekday?(match[1], verbose)
          entry = {
            :date    => match[1],
            :version => match[3],
            :release => match[4],
            :content => changelog_lines
          }
          changelogs << entry
        else
          warn "WARNING: Parsing stopped at invalid changelog entry: \n#{entry}" if verbose
          break
        end
      end
    end

    changelogs
  end

  # Validate the weekday in the already-format-verified changelog
  # date string is correct for the date specified
  #
  # Returns false if the weekday is incorrect for date specified.
  #
  # +changelog_date+:: Date string of the form <weekday> <month> <day> <year>
  # +verbose+:: Whether to log details about a weekday validation failure
  def valid_date_weekday?(changelog_date, verbose)
    date = Date.strptime(changelog_date, '%a %b %d %Y')
    expected_weekday = date.strftime('%a')
    actual_weekday = changelog_date.strip.split[0]

    valid = true
    if actual_weekday != expected_weekday
      err_msg = ERR_MARKER + "'#{actual_weekday}' should be '#{expected_weekday}' for" +
        " changelog timestamp '#{changelog_date}'"
      warn err_msg if verbose
      valid = false
    end
    return valid
  end

end
