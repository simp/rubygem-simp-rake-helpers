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

        Rake::Task["pkg:#{type}"].invoke
      end

      task :clobber do |t,args|
        advanced_clean('clobber',args)
      end

      task :clean do |t,args|
        advanced_clean('clean',args)
      end
    end
  end
end
