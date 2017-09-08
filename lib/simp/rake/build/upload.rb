#!/usr/bin/rake -T
require 'open3'
require 'simp/rpm'
require 'simp/rake/build/constants'

module Simp; end
module Simp::Rake; end
module Simp::Rake::Build

  class Upload < ::Rake::TaskLib
    include Simp::Rake::Build::Constants

    def initialize( base_dir )
      init_member_vars( base_dir )

      define_tasks
    end

    def define_tasks

      namespace :upload do
        task :prep do
          if $simp6
            @build_dir = $simp6_build_dir
          end
        end

        ##############################################################################
        # Helper methods
        ##############################################################################

        # Get a list of all packages that have been updated since the passed
        # date or git identifier (tag, branch, or commit).

        def get_updated_packages(start,script_format)
          pkg_info = Hash.new
          printed_info = false

          to_check = []
          # Find all static RPMs and GPGKEYS that we may need to update so
          # that we can see if we have newer versions to upload!
          Find.find(@build_dir) do |file|
            next if file == @build_dir
            Find.prune if file !~ /^#{@build_dir}\/(Ext.*(\.rpm)?|GPGKEYS)/
            to_check << file if File.file?(file)
          end

          # Smash in all of the file files!
          to_check += Dir.glob("#{@spec_dir}/*.spec")
          to_check += Dir.glob("#{@src_dir}/puppet/modules/*/pkg/*.spec")

          to_check.each do |file|

            is_commit = false
            oldstart = start
            humanstart = ''
            # Before changing the directory, see if we've got a commit or a
            # date. If we've got a tag or branch from the top level, then we
            # need to get the date from there and use it later.
            Dir.chdir(@spec_dir) do
              stdin,stdout,stderr = Open3.popen3('git','rev-list',start)
              stderr.read !~ /^fatal:/ and is_commit = true

              if is_commit
                # Snag the date.
                start, humanstart = `git log #{start} --pretty=format:"%ct##%cd" --max-count=1`.chomp.split('##')
              else
                printed_info = true
              end
            end

            !printed_info and puts "Info: Comparing to '#{humanstart}' based on input of '#{oldstart}'"

            Dir.chdir(File.dirname(file)) do
              # Get the file HEAD commit
              # If we're not in a git repo, this will explode, but that's just
              # fine.
              current_head = `git rev-list HEAD --max-count=1`.chomp

              begin
                # Convert the spec files to something more human readable...
                pkg_info[file] = {
                  :is_new => false
                }
                pkg_info[file][:alias] = file
                if file =~ /.spec$/
                  if script_format
                    pkg_info[file][:alias] = "#{@build_dir}/RPMS/#{Simp::RPM.new(file).name}*.rpm"
                  else
                    pkg_info[file][:alias] = Simp::RPM.new(file).name
                  end
                end
              rescue
                raise "Error: There was an issue getting information from #{file}"
              end

              commit_head = nil
              # It turns out that an invalid date will just return
              # everything
              commit_head = `git log --before="#{start}" --pretty=format:%H --max-count=1 #{File.basename(file)}`.chomp

              # Did we find something different?
              if commit_head.empty?
                pkg_info[file][:is_new] = true
              else
                pkg_info[file][:is_new] = !system('git','diff','--quiet',commit_head,File.basename(file))
              end
            end
          end

          return pkg_info
        end

=begin
        desc <<-EOM
          Get a list of modified packages.

          The package list is created from the given date or git identifier (tag, branch, or hash)
        EOM
=end
        task :get_modified,[:start,:script_format] => [:prep] do |t,args|
          args.with_defaults(:script_format => false)

          args.start or raise "Error: You must specify a 'start'"

          updated_pkgs = get_updated_packages(args.start, args.script_format)
          updated_pkgs.keys.sort.each do |k|
            updated_pkgs[k][:is_new] and puts "Updated: #{updated_pkgs[k][:alias]}"
          end
        end
      end
    end
  end
end
