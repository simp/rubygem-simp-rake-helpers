require 'simp/rake'
require 'simp/rake/build/constants'

module Simp; end
module Simp::Rake; end
module Simp::Rake::Build

  class Iso < ::Rake::TaskLib
    include Simp::Rake
    include Simp::Rake::Build::Constants

    def initialize( base_dir )
      init_member_vars( base_dir )

      define_tasks
    end

    def verbose
      ENV.fetch('SIMP_ISO_verbose','no') == 'yes'
    end

    def define_tasks

      File.umask(0007)

      namespace :iso do
        task :prep do
          if $simp6
            @build_dir = $simp6_build_dir
          end
        end

        # Remove packages from the given directory. The goal of this method is to help
        # get the distro to be as small as possible.
        # [:from_dir] Root directory to remove packages from (removes recursively)
        # [:exclude_dirs] Array of directories to not remove any packages from
        # [:exclude_pkgs] Array of packages to not remove
        def prune_packages(from_dir,exclude_dirs,exclude_pkgs,mkrepo='createrepo -p',use_hack=true)
          $stderr.puts "Starting to prune..."
          Dir.chdir(from_dir) do
            prune_count = 0

            Find.find('.') do |path|
              Find.prune if exclude_dirs.include?(File.basename(path))

              if File.basename(path) =~ /.*\.rpm/
                # Get the package name from the RPM.
                # Note: an alternative method may be to just simply check the names
                # of the RPMs themselves instead of the names of the packages.
                pkg = nil
                if use_hack
                  # The proper way (defined below) is way too slow, so this hack helps
                  # speed up the process by reading the file directly. If the code is
                  # not working, attempt this without using the hack, just be ready
                  # to wait a long time for the code to complete.
                  pkgname = File.basename(path).split('-').first
                  File.open(path,'r').each_line do |line|
                    if encode_line(line) =~ /C\000(\S+\000)?(#{Regexp.escape(pkgname)}\S*)\000/
                      pkg = $2.split(/\000/).first
                      break
                    end
                  end
                else
                  # Proper way to obtain the RPM's package name, but WAY too slow
                  pkg = %x{rpm -qp --qf "%{NAME}" #{path} 2>/dev/null}.chomp
                end

                unless exclude_pkgs.include?(pkg)
                  rm(path, :verbose => verbose)
                  prune_count += 1
                end
              end
            end
            $stderr.puts "Info: Pruned #{prune_count} packages from #{from_dir}"

            if prune_count > 0
              # Recreate the now-pruned repos
              basepath = '.'
              if (File.basename(from_dir) =~ /^RHEL/)
                # This covers old versions of RHEL that don't follow the new
                # way of doing things.
                unless Dir.glob("Server/*.rpm").empty?
                  basepath = 'Server'
                end
              end

              Dir.chdir(basepath) do
                cp(Dir.glob("repodata/*comps*.xml").first,"simp_comps.xml")
                sh %{#{mkrepo} -g simp_comps.xml .}
                rm("simp_comps.xml")
              end
            end
          end
        end # End of prune_packages

=begin
        desc <<-EOM
      Build the SIMP ISO(s).
       * :tarball - Path of the source tarball or directory containing the source
           tarballs.
       * :unpacked_dvds - Path of the directory containing the unpacked base OS
           directories. Default is the current directory.
       * :prune - Flag for whether unwanted packages should be pruned prior to
           building the ISO. Default is true.

       ENV vars:
         - Set `SIMP_ISO_verbose=yes` to report file operations as they happen.
           EOM
=end
        task :build,[:tarball,:unpacked_dvds,:prune] => [:prep] do |t,args|
          args.with_defaults(:unpacked_dvds => "#{@run_dir}", :prune => 'true')

          if args.tarball.nil?
            fail("Error: You must specify a source tarball or tarball directory!")
          else
            tarball = File.expand_path(args.tarball)

            unless File.exist?(tarball)
              fail("Error: Could not find tarball at '#{tarball}'!")
            end
          end

          tarfiles = File.directory?(tarball) ?
            Dir.glob("#{tarball}/*.tar.gz") : [tarball]
          vermap = YAML::load_file( File.join( File.dirname(__FILE__), 'vermap.yaml'))

          tarfiles.each do |tball|
            namepieces = File.basename(tarball,".tar.gz").split('-')

            # SIMP 6
            if namepieces[1] =~ /^\d/
              simpver = namepieces[1..2].join('-')
              baseos  = namepieces[3]
            else
              simpver = namepieces[3..-1].join('-')
              baseos  = namepieces[2]
            end

            iso_dirs = Dir.glob("#{File.expand_path(args.unpacked_dvds)}/#{baseos}*")
            if iso_dirs.empty?
              fail("Error: No unpacked DVD directories found for '#{baseos}' under '#{File.expand_path(args.unpacked_dvds)}'")
            end

            # Process each unpacked base OS ISO directory found
            iso_dirs.each do |dir|
              baseosver = '???'
              arch      = '???'

              # read the .treeinfo file (INI format)
              # ------------------------------------
              require 'puppet'
              require 'puppet/util/inifile'

              file = "#{dir}/.treeinfo"
              fail("ERROR: no file '#{file}'") unless File.file?(file)

              ini = Puppet::Util::IniConfig::PhysicalFile.new(file)
              ini.read
              sections = ini.sections.map{ |s| s.name }

              # NOTE: RHEL7 discs claim [general] section is deprecated.
              if sections.include?('general')
                h = Hash[ ini.get_section('general').entries.map{|k,v| [k,v]} ]
                arch      = h.fetch('arch', arch).strip
                baseosver = h.fetch('version', baseosver).strip
                baseosver += '.0' if (baseosver.count('.') < 1)
              end
              # ------------------------------------

              # Skip if SIMP version doesn't match target base OS version
              unless Array(vermap[simpver.split('.').first]).include?(baseosver.split('.').first)
                if verbose
                  warn("Could not find SIMP version mapping for #{simpver} for Base OS #{baseosver}")
                end

                next
              end

              mkrepo = baseosver.split('.').first == '5' ? 'createrepo -s sha -p' : 'createrepo -p'

              @simp_dvd_dirs.each do |clean_dir|
                if File.directory?("#{dir}/#{clean_dir}")
                  rm_rf("#{dir}/#{clean_dir}", :verbose => verbose)
                elsif File.file?("#{dir}/#{clean_dir}")
                  fail("Error: #{dir}/#{clean_dir} is a file, expecting directory!")
                end
              end

              # Prune unwanted packages
              begin
                system("tar --no-same-permissions -C #{dir} -xzf #{tball} *simp_pkglist.txt")
              rescue
                # Does not matter if the command fails
              end

              pkglist_file = ENV.fetch(
                'SIMP_PKGLIST_FILE',
                File.join(dir,"#{baseosver.split('.').first}-simp_pkglist.txt")
              )

              puts
              puts '-'*80
              puts "### Pruning packages not in file '#{pkglist_file}'"
              puts
              puts '   (override this with `SIMP_PKGLIST_FILE=<file>`)'
              puts
              puts '-'*80
              puts

              if (args.prune.casecmp("false") != 0) && File.exist?(pkglist_file)
                exclude_pkgs = Array.new
                File.read(pkglist_file).each_line do |line|
                  next if line =~ /^(\s+|#.*)$/
                  exclude_pkgs.push(line.chomp)
                end
                prune_packages(dir,['SIMP'],exclude_pkgs,mkrepo)
              end

              # Add the SIMP code
              system("tar --no-same-permissions -C #{dir} -xzf #{tball}")

              Dir.chdir("#{dir}/SIMP") do
                # Add the SIMP Dependencies
                simp_base_ver = simpver.split('-').first

                if $simp6
                  yum_dep_location = File.join(@build_dir,'yum_data','packages')
                else
                  simp_dep_src = %(SIMP#{simp_base_ver}_#{baseos}#{baseosver}_#{arch})
                  yum_dep_location = File.join(@build_dir,'yum_data',simp_dep_src,'packages')
                end

                unless File.directory?(yum_dep_location)
                  fail("Could not find dependency directory at #{yum_dep_location}")
                end

                yum_dep_rpms = Dir.glob(File.join(yum_dep_location,'*.rpm'))
                if yum_dep_rpms.empty?
                  fail("Could not find any dependency RPMs at #{yum_dep_location}")
                end

                # Add any one-off RPMs that you might want to add to your own build
                # These are *not* checked to make sure that they actually match your
                # environment
                aux_packages = File.join(File.dirname(yum_dep_location),'aux_packages')
                if File.directory?(aux_packages)
                  yum_dep_rpms += Dir.glob(File.join(aux_packages,'*.rpm'))
                end

                yum_dep_rpms.each do |rpm|
                  rpm_arch = rpm.split('.')[-2]

                  unless File.directory?(rpm_arch)
                    mkdir(rpm_arch)
                  end

                  # Just in case this is a symlink, broken, or some other nonsense.
                  target_file = File.join(rpm_arch,File.basename(rpm))
                  rm_f(target_file) if File.exist?(target_file)

                  cp(rpm,rpm_arch, :verbose => verbose)
                end

                fail("Could not find architecture '#{arch}' in the SIMP distribution") unless File.directory?(arch)
                # Get everything set up properly...
                Dir.chdir(arch) do
                  Dir.glob('../*') do |rpm_dir|
                    # Don't dive into ourselves
                    next if File.basename(rpm_dir) == arch

                    Dir.glob(%(#{rpm_dir}/*.rpm)) do |source_rpm|
                      link_target = File.basename(source_rpm)
                      if File.exist?(source_rpm) && File.exist?(link_target)
                        next if Pathname.new(source_rpm).realpath == Pathname.new(link_target).realpath
                      end

                      ln_sf(source_rpm,link_target, :verbose => verbose)
                    end
                  end

                  fail("Error: Could not run createrepo in #{Dir.pwd}") unless system(%(#{mkrepo} .))
                end
              end

              # Make sure we have all of the necessary RPMs!
              Rake::Task['pkg:repoclosure'].invoke(File.expand_path(dir))

              # Do some sane chmod'ing and build ISO
              system("chmod -fR u+rwX,g+rX,o=g #{dir}")
              simp_output_name = "SIMP-#{simpver}-#{baseos}-#{baseosver}-#{arch}"
              @simp_output_iso = "#{simp_output_name}.iso"

              mkisofs_cmd = [
                'mkisofs',
                "-A SIMP-#{simpver}",
                "-V SIMP-#{simpver}",
                "-volset SIMP-#{simpver}",
                '-uid 0',
                '-gid 0',
                '-J',
                '-joliet-long',
                '-r',
                '-v',
                '-T',
                '-b isolinux/isolinux.bin',
                '-c boot.cat',
                '-boot-load-size 4',
                '-boot-info-table',
                '-no-emul-boot',
                '-m TRANS.TBL',
                '-x ./lost+found',
                "-o #{@simp_output_iso}",
                dir
              ]

              system(mkisofs_cmd.join(' '))
            end
          end # End of tarfiles loop

          # If we got here and didn't generate any ISOs, something went horribly wrong
          fail('Error: No ISO was built!') unless @simp_output_iso
        end

=begin
        desc <<-EOM
        Build the source ISO.
          Note: The process clobbers the temporary and built files, rebuilds the
          tarball(s) and packages the source ISO. Therefore it will take a
          while.
            * :key - The GPG key to sign the RPMs with. Defaults to 'prod'.
        EOM
=end
        task :src,[:prep, :key] do |t,args|
          args.with_defaults(:key => 'prod')

          if Dir.glob("#{@dvd_dir}/*.gz").empty?
            fail("Error: Could not find compiled source tarballs")
          end

          Rake::Task['tar:build']

          Dir.chdir(@base_dir) do
            File.basename(Dir.glob("#{@dvd_dir}/*.tar.gz").first,'.tar.gz') =~ /SIMP-DVD-[^-]+-(.+)/
            name = "SIMP-#{$1}"
            sh %{mkisofs -uid 0 -gid 0 -D -A #{name} -J -joliet-long -m ".git*" -m "./build/tmp" -m "./build/SRPMS" -m "./build/RPMS" -m "./build/build_keys" -o #{name}.src.iso .}
          end
        end
      end
    end
  end
end
