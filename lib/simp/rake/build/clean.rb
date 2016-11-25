require 'simp/rake/build/constants'

module Simp; end
module Simp::Rake; end
module Simp::Rake::Build

  class Clean < ::Rake::TaskLib
    include Simp::Rake::Build::Constants

    def initialize( base_dir )
      init_member_vars( base_dir )
      define_tasks
    end

    def define_tasks
      ::CLEAN.include(
        "#{@dist_dir}/*",
        ".discinfo",
        @dvd_dir,
        "#{@build_dir}/SIMP",
        "#{@base_dir}/SIMP_ISO*"
      )

      if $simp6_build_dirs
        ::CLEAN.include($simp6_clean_dirs)
      end

      ::CLOBBER.include(
        @dist_dir,
        "#{@build_dir}/build_keys/dev",
        "#{@build_dir}/yum_data/*/packages"
      )

      # This just abstracts the clean/clobber space in such a way that clobber can actally be used!
      def advanced_clean(type,args)
        fail "Type must be one of 'clean' or 'clobber'" unless ['clean','clobber'].include?(type)

        validate_in_mock_group?

        mock_dirs = Dir.glob("/var/lib/mock/*").map{|x| x = File.basename(x) }

        unless ( mock_dirs.empty? or args.chroot )
          $stderr.puts "Notice: You must pass a Mock chroot to erase a specified build root."
        end

        Rake::Task["pkg:#{type}"].invoke(args.chroot)
      end

      task :clobber,[:chroot] do |t,args|
        advanced_clean('clobber',args)
      end

      task :clean,[:chroot] do |t,args|
        advanced_clean('clean',args)
      end
    end
  end
end
