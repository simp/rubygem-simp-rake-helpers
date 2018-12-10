# This file provided many common build-related tasks and helper methods from
# the SIMP Rakefile ecosystem.

require 'rake'
require 'rake/clean'
require 'rake/tasklib'
require 'fileutils'
require 'simp/relchecks'
require 'simp/rpm/builder'
require 'simp/rpm/packageinfo'
require 'simp/rpm/specfileinfo'
require 'simp/rpm/utils'

module Simp; end
module Simp::Rake
  class Pkg < ::Rake::TaskLib

    # Array of items to additionally clean
    # TODO Figure out why each entity using the clean_list setter does
    # not add to ::CLEAN/::CLOBBER themselves?
    attr_accessor :clean_list

#FIXME Explain environment variables used to inject configuration
#
    def initialize( base_dir )
      @base_dir     = base_dir
      @pkg_name     = File.basename(@base_dir)

      @simp_version = ENV['SIMP_BUILD_version']

#FIXME This is clunky.  SIMP_RAKE_PKG_verbose should be true, false, or
#      a number and SIMP_RPM_verbose should be eliminated
      @verbose      = ENV.fetch('SIMP_RAKE_PKG_verbose','no') == 'yes'

      @verbosity = 0
      if @verbose
        if ( ENV.fetch('SIMP_RPM_verbose','no') == 'yes')
          @verbosity = 2
        else
          @verbosity = 1
        end
      end

      @build_rpm_macros = []
      unless ENV['SIMP_RPM_macros'].nil?
        @build_rpm_macros += ENV['SIMP_RPM_macros'].split(',')
      end

      if (ENV.fetch('SIMP_RAKE_PKG_LUA_verbose','no') =='yes')
        @build_rpm_macros << 'lua_debug:1'
      end

      # This is only meant to be used to work around the case where particular
      # packages need to ignore some set of artifacts that get updated out of
      # band. This should not be set as a regular environment variable and
      # should be fixed properly at some time in the future.
      #
      # Presently, this is used by simp-doc
      @ignore_changes_list = nil
      if ENV['SIMP_INTERNAL_pkg_ignore']
        @ignore_changes_list = Simp::Rpm::Builder::DEFAULT_IGNORE_CHANGES_LIST
        @ignore_changes_list += ENV['SIMP_INTERNAL_pkg_ignore'].split(',')
      end

      pkg_dir = File.join(@base_dir, Simp::Rpm::Builder::DEFAULT_ARTIFACT_DIR)
      ::CLEAN.include( pkg_dir )

      # This block is provided to allow customization of the clean list
      @clean_list    = []
      yield self if block_given?
      ::CLEAN.include( @clean_list )

      define
    end

    def define
      # For the most part, we don't want to hear Rake's noise, unless it's an error
      # TODO: Make this configurable
      verbose(false)

      define_clean
      define_clobber
      define_pkg_check_rpm_changelog
      define_pkg_check_version
      define_pkg_compare_latest_tag
      define_pkg_create_tag_changelog
      define_pkg_rpm
      task :default => 'pkg:rpm'

#TODO Figure out the purpose of the following line.  Weren't the defines sufficient?
      Rake::Task['pkg:rpm']

      self
    end

    def define_clean
      desc <<-EOM
      Clean build artifacts for #{@pkg_name}
      EOM
      task :clean do |t,args|
        # this is provided by 'rake/clean' and the ::CLEAN constant
      end
    end

    def define_clobber
      desc <<-EOM
      Clobber build artifacts for #{@pkg_name}
      EOM
      task :clobber do |t,args|
      end
    end

    def define_pkg_rpm

      # :pkg:rpm
      # -----------------------------
      namespace :pkg do
=begin
        WARNING: THIS DOES NOT PULL FROM THE simp-core RPM DEPENDENCIES FILE
        WARNING: YOU WILL PROBABLY NOT GET PROPER FULL SIMP RPMS FROM THIS TASK

        desc <<-EOM
        Build the #{@pkg_name} RPM.

            By default, the package will be built to support a SIMP-6.X file structure.
        EOM
FIXME add description of macros
=end

        task :rpm  do |t,args|

          opts = {
            :rpm_macros   => @build_rpm_macros,
            :simp_version => @simp_version,
            :verbosity    => @verbosity
          }

          unless @ignore_changes_list.nil?
            opts[:ignore_changes_list] = @ignore_changes_list
          end

          Simp::Rpm::Builder.new(@base_dir, opts).build
        end
      end
    end

   def define_pkg_check_rpm_changelog
      # :pkg:check_rpm_changelog
      # -----------------------------
      namespace :pkg do
        desc <<-EOM
#{Simp::Utils::indent(Simp::RelChecks::CHECK_RPM_CHANGELOG_DESCRIPTION.gsub(/a component's/,"the #{@pkg_name}"), 8)}

          ARGS:
            * :verbose => Set to 'true' if you want to see detailed messages
        EOM
        task :check_rpm_changelog, [:verbose] do |t,args|
          verbose = ( args[:verbose].to_s == 'true' )

          Simp::RelChecks::check_rpm_changelog(@base_dir, @simp_version, verbose)
        end
      end
    end

    def define_pkg_check_version
      namespace :pkg do
        # :pkg:check_version
        # -----------------------------
        desc <<-EOM
        Ensure that #{@pkg_name} has a properly updated version number.
        EOM
        task :check_version do |t,args|
#FIXME Understand how this differs from Simp::RelChecks::compare_latest_tag
#      and, if we still want this, move this code to Simp::RelChecks
          require 'json'

          # Get the current version
          if File.exist?('metadata.json')
            mod_version = JSON.load(File.read('metadata.json'))['version'].strip
            success_msg = "#{@pkg_name}: Version #{mod_version} up to date"

            # If we have no tags, we need a new version
            if %x(git tag).strip.empty?
              puts "#{@pkg_name}: New Version Required"
            else
              # See if the module is newer than all tags
              matching_tag = %x(git tag --points-at HEAD).strip.split("\n").first

              if matching_tag.nil? || matching_tag.empty?
                # We don't have a matching release
                # Get the closest tag
                nearest_tag = %x(git describe --abbrev=0 --tags).strip

                if mod_version == nearest_tag
                  puts "#{@pkg_name}: Error: metadata.json needs to be updated past #{mod_version}"
                else
                  # Check the CHANGELOG Version
                  if File.exist?('CHANGELOG')
                    changelog = File.read('CHANGELOG')
                    changelog_version = nil

                    # Find the first date line
                    changelog.each_line do |line|
                      if line =~ /\*.*(\d+\.\d+\.\d+)(-\d+)?\s*$/
                        changelog_version = $1
                        break
                      end
                    end

                    if changelog_version
                      if changelog_version == mod_version
                        puts success_msg
                      else
                        puts "#{@pkg_name}: Error: CHANGELOG version #{changelog_version} out of date for version #{mod_version}"
                      end
                    else
                      puts "#{@pkg_name}: Error: No CHANGELOG version found"
                    end
                  else
                    puts "#{@pkg_name}: Warning: No CHANGELOG found"
                  end
                end
              else
                if mod_version != matching_tag
                  puts "#{@pkg_name}: Error: Tag #{matching_tag} does not match version #{mod_version}"
                else
                  puts success_msg
                end
              end
            end
          else
            puts "#{@pkg_name}: No metadata.json found"
          end
        end
      end
    end

    def define_pkg_compare_latest_tag
      namespace :pkg do
        desc <<-EOM
        Compare to latest tag.
          ARGS:
            * :tags_source => Set to the remote from which the tags for this
                              project can be fetched. Defaults to 'origin'.
            * :verbose => Set to 'true' if you want to see detailed messages

#{Simp::Utils::indent(Simp::RelChecks::COMPARE_LATEST_TAG_DESCRIPTION, 8)}
        EOM
        task :compare_latest_tag, [:tags_source, :verbose] do |t,args|
          tags_source = args[:tags_source].nil? ? 'origin' : args[:tags_source]
          verbose = ( args[:verbose].to_s == 'true')
          Simp::RelChecks::compare_latest_tag(@base_dir, tags_source, verbose)
        end
      end
    end

    def define_pkg_create_tag_changelog
      namespace :pkg do
        # :pkg:create_tag_changelog
        # -----------------------------
        desc <<-EOM
        Create a tag changelog
          ARGS:
            * verbose => Set to 'true' if you want to see
              non-catestrophic warning messages.

#{Simp::Utils::indent(Simp::RelChecks::CREATE_TAG_CHANGELOG_DESCRIPTION.gsub(/a component's/,"the #{@pkg_name}"), 8)}
        EOM

        task :create_tag_changelog, [:verbose] => [:check_rpm_changelog] do |t,args|
          verbose = ( args[:verbose].to_s == 'true')
          puts Simp::RelChecks::create_tag_changelog(@base_dir, verbose)
        end
      end
    end
  end
end
