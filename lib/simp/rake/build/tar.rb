#!/usr/bin/rake -T

require 'simp/rake/build/constants'

module Simp; end
module Simp::Rake; end
module Simp::Rake::Build

  class Tar < ::Rake::TaskLib
    include Simp::Rake::Build::Constants

    def initialize( base_dir )
      init_member_vars( base_dir )

      define_tasks
    end

    # define rake tasks
    def define_tasks
      namespace :tar do
        task :prep do
          if $simp6
            @build_dir = $simp6_build_dir || @distro_build_dir
            @dvd_src = File.join(@build_dir, File.basename(@dvd_src))
          end

          if $tarball_tgt
            @dvd_dir = File.dirname($tarball_tgt)
          end
        end

        def get_simp_version
          simp_rpm = Dir.glob("#{@build_dir}/SIMP/RPMS/*/simp-[0-9]*.rpm").max_by {|f| File.mtime(f)}
          fail("Could not find simp main RPM in output directory!") unless simp_rpm

          simp_version = Simp::RPM.new(simp_rpm).full_version

          # For picking up the correct RPM template
          ENV['SIMP_BUILD_version'] ||= simp_version

          return simp_version
        end

        ##############################################################################
        # Main tasks
        ##############################################################################

        task :validate => [:prep] do |t,args|
          required_rpms = {
            'noarch' => [
              'rubygem-simp-cli',
              'simp',
              'simp-gpgkeys',
              'simp-utils',
              'simp-vendored-r10k'
            ]
          }

          simp_version = get_simp_version

          if Gem::Version.new(simp_version) < Gem::Version.new('6.4.0')
            required_rpms['noarch'] << 'simp-rsync'
          else
            required_rpms['noarch'] << 'simp-rsync-skeleton'
            required_rpms['noarch'] << 'simp-environment-skeleton'
            required_rpms['noarch'] << 'simp-selinux-policy'
          end

          rpm_dir = File.join(@build_dir,'SIMP','RPMS')
          fail("Could not find directory '#{rpm_dir}'") unless File.directory?(rpm_dir)

          Dir.chdir(rpm_dir) do
            failures = []
            required_rpms.keys.each do |dir|
              fail("Could not find directory '#{File.join(rpm_dir, dir)}'") unless File.directory?(dir)

              Dir.chdir(dir) do
                required_rpms[dir].each do |pkg|
                  if Dir.glob("#{pkg}-[0-9]*.rpm").empty?
                    failures << "  * #{pkg}"
                  end
                end
              end
            end

            unless failures.empty?
              msg = ['Error: Could not find the following packages:'] +
                failures +
                ['Did "dist/logs/last_rpm_build_metadata.yaml" get generated in the build directory?']

              fail(msg.join("\n"))
            end
          end
        end

=begin
        desc <<-EOM
          Build the DVD tarball(s).

            * :key - What key to use for signing the RPMs
            * :docs - Whether or not to build the documentation
        EOM
=end
        task :build,[:key,:docs] => ['pkg:build','pkg:checksig','tar:validate'] do |t,args|
          args.with_defaults(:docs => 'true')

          if $tarball_tgt
            target_dists = ['simp6']
          else
            target_dists = @target_dists
          end

          Parallel.map(
            target_dists,
            :in_processes => get_cpu_limit,
            :process => t.name
          ) do |dist|
            if $tarball_tgt
              base_dir = "#{@dvd_dir}/staging"
            else
              base_dir = "#{@dvd_dir}/#{dist}/staging"
            end

            destdir = "#{base_dir}/SIMP"

            # Build the staging area
            remove_entry_secure(destdir) if File.exist?(destdir)

            mkdir_p(destdir)

            Simp::RPM.copy_wo_vcs(@dvd_src,".",base_dir)

            # Copy in the GPG Public Keys from @build_dir
            mkdir_p("#{destdir}/GPGKEYS")
            ln(Dir.glob("#{@build_dir}/GPGKEYS/RPM-GPG-KEY*"), "#{destdir}/GPGKEYS", { :force => true })

            # Copy in the GPG Public Keys packaged by simp-gpgkeys
            simp_gpgkeys = File.join(@src_dir, 'assets', 'gpgkeys', 'GPGKEYS')
            if Dir.exist?(simp_gpgkeys)
              ln(Dir.glob("#{simp_gpgkeys}/RPM-GPG-KEY*"), "#{destdir}/GPGKEYS", { :force => true })
            end

            # Copy in the auto-build RPMs
            Dir.chdir("#{@build_dir}/SIMP/RPMS") do
              Dir.glob('*').each do |type|
                dest_type = type
                if File.directory?(type)
                  if type =~ /i.*86/
                    dest_type = 'i386'
                  end

                  mkdir_p("#{destdir}/#{dest_type}")

                  Dir.chdir(type) do
                    ln(Dir.glob("*.#{type}.rpm"), "#{destdir}/#{dest_type}", { :force => true })
                  end
                end
              end
            end

            if args.docs.casecmp('true') == 0
              # Finally, the PDF docs if they exist.
              pdfs = Dir.glob("#{@src_dir}/doc/pdf/*")
              unless pdfs.empty?
                pdfs.each do |pdf|
                  cp(pdf,base_dir)
                end
              else
                # If we don't have PDFs in the directory, yank them out of the
                # RPM itself!
                simp_doc_rpm = Dir.glob("#{@build_dir}/SIMP/RPMS/*/simp-doc*.rpm").last
                unless simp_doc_rpm
                  raise(StandardError,"Error: Could not find simp-doc*.rpm in the build, something went very wrong")
                end

                Dir.mktmpdir do |dir|
                  Dir.chdir(dir) do
                    %x{rpm2cpio #{simp_doc_rpm} | cpio -u --quiet --warning none -ivd ./usr/share/doc/simp-*/pdf/SIMP*.pdf 2>&1 > /dev/null}
                    pdf_docs = Dir.glob("usr/share/doc/simp-*/pdf/*.pdf")

                    if pdf_docs.empty?
                      raise(StandardError,"Error: Could not find any PDFs in the simp-doc RPM, aborting.")
                    end

                    pdf_docs.each do |pdf|
                      cp(pdf,base_dir)
                    end
                  end
                end
              end
            end
          end

          # FIXME: this is a horribad way of sharing with `build:auto`
          $simp_tarballs = {}

          if $tarball_tgt
            target_dists = ['simp6']
          else
            target_dists = @target_dists
          end

          target_dists.each do |dist|
            if $tarball_tgt
              dvd_tarball = File.basename($tarball_tgt)
              base_dir = "#{@dvd_dir}/staging"
            else
              base_dir = "#{@dvd_dir}/#{dist}/staging"
              dvd_name = [ 'SIMP', 'DVD', dist, get_simp_version ]
              dvd_tarball = "#{dvd_name.join('-')}.tar.gz"
            end

            mkdir_p(base_dir)

            Dir.chdir(base_dir) do
              sh %{tar --owner 0 --group 0 --exclude-vcs --mode=u=rwX,g=rX,o=rX -cpzf "../#{dvd_tarball}" ./*}
              unless $tarball_tgt
                mv("../#{dvd_tarball}",@dvd_dir)
              end
            end

            puts "Package DVD: #{@dvd_dir}/#{dvd_tarball}"
            $simp_tarballs[dist] = "#{@dvd_dir}/#{dvd_tarball}"
            rm_rf(base_dir)
          end
        end
      end
    end
  end
end

