#!/usr/bin/rake -T

require 'simp/rake/pkg'
require 'simp/rake/build/constants'

module Simp; end
module Simp::Rake; end
module Simp::Rake::Build

  class Pkg < ::Rake::TaskLib
    include Simp::Rake
    include Simp::Rake::Build::Constants

    def initialize( base_dir )
      init_member_vars( base_dir )
      @mock = ENV['mock'] || '/usr/bin/mock'
      define_tasks
    end

    def define_tasks
      task :help do
        puts <<-EOF.gsub(/^  /, '')
          SIMP_RAKE_CHOWN_EVERYTHING=(Y|N)
              If 'Y', builds are preceded by a massive chown -R mock on the entire source tree

          EOF
      end

      namespace :pkg do

        ##############################################################################
        # Main tasks
        ##############################################################################

        # Have to get things set up inside the proper namespace
        task :prep,[:method] do |t,args|
          args.with_defaults(:method => 'tracking')

          @build_dirs = {
            :modules => get_module_dirs(args[:method]),
            :aux => [
              "#{@build_dir}/GPGKEYS",
              "#{@src_dir}/rsync",
              # Anything in here gets built!
              "#{@src_dir}/assets/*",
              # Legacy Compat
              "#{@src_dir}/utils",
              "#{@src_dir}/puppet/bootstrap"
            ],
            :doc => "#{@src_dir}/doc",
            :simp_cli => "#{@src_dir}/rubygems/simp_cli",
            :simp => "#{@src_dir}",
          }

          @build_dirs[:aux].map!{|dir| dir = Dir.glob(dir)}
          @build_dirs[:aux].flatten!
          @build_dirs[:aux].delete_if{|f| !File.directory?(f)}

          @pkg_dirs = {
            :simp => "#{@build_dir}/SIMP",
            :ext  => "#{@build_dir}/Ext_*"
          }
        end

        task :mock_prep do
          chown_everything = ENV.fetch( 'SIMP_RAKE_CHOWN_EVERYTHING', 'Y' ).chomp.index( %r{^(1|Y|true|yes)$}i ) || false

          verbose(true) do
            next unless chown_everything

            dirs_to_mod = []
            files_to_mod = []

            Find.find(@base_dir) do |path|
              Find.prune if File.symlink?(path)
              Find.prune if (File.basename(path) == '.git')
              Find.prune if (File.basename(path) =~ /^\..*cache/)

              safe_path = Shellwords.escape(path)

              mock_gid = Etc.getgrnam('mock').gid

              file_stat = File.stat(path)

              file_mode = file_stat.mode.to_s(2)[-12..-1].scan(/.{3}/)
              file_group_perms = file_mode[-2]
              file_group_read = (file_group_perms[0] == '1')
              file_group_execute = (file_group_perms[2] == '1')
              file_sgid = (file_mode[-4][1] == '1')

              if File.directory?(path)
                if (mock_gid != file_stat.gid) ||
                    !file_group_read ||!file_group_execute || !file_sgid
                  dirs_to_mod << safe_path
                end
              else
                if (mock_gid != file_stat.gid) || !file_group_read
                  files_to_mod << safe_path
                end
              end
            end

            # Set the permissions properly for mock to dig through your source
            Parallel.map(
              dirs_to_mod,
              :in_processes => get_cpu_limit,
              :progress => 'Set "mock" dir perms'
            ) do |dir|
              %x{chgrp 'mock' #{dir} && chmod g+rXs #{dir}}
            end

            Parallel.map(
              files_to_mod,
              :in_processes => get_cpu_limit,
              :progress => 'Set "mock" file perms'
            ) do |file|
              %x{chgrp 'mock' #{file} && chmod g+r #{file}}
            end
          end
        end

        clean_failures = []
        clean_failures_lock = Mutex.new
        chroot_scrub_lock = Mutex.new

        task :clean,[:chroot] => [:prep] do |t,args|
          validate_in_mock_group?
          @build_dirs.each_pair do |k,dirs|
            Parallel.map(
              Array(dirs),
              :in_processes => get_cpu_limit,
              :progress => t.name
            ) do |dir|
              Dir.chdir(dir) do
                begin
                  rake_flags = Rake.application.options.trace ? '--trace' : ''
                  %x{rake clean[#{args[:chroot]}] #{rake_flags}}
                  clean_failures_lock.synchronize do
                    clean_failures << dir unless $?.success?
                  end
                rescue Exception => e
                  clean_failures_lock.synchronize do
                    clean_failures << dir
                  end
                  raise Parallel::Kill
                end
              end
            end
          end

          unless clean_failures.empty?
            fail(%(Error: The following directories had failures in #{task.name}:\n  * #{clean_failures.join("\n  * ")}))
          end

          %x{mock -r #{args[:chroot]} --scrub=all} if args[:chroot]
        end

        task :clobber,[:chroot] => [:prep] do |t,args|
          validate_in_mock_group?
          @build_dirs.each_pair do |k,dirs|
            Parallel.map(
              Array(dirs),
              :in_processes => get_cpu_limit,
              :progress => t.name
            ) do |dir|
              Dir.chdir(dir) do
                rake_flags = Rake.application.options.trace ? '--trace' : ''
                sh %{rake clobber[#{args[:chroot]}] #{rake_flags}}
              end
            end
          end
        end

        desc <<-EOM
          Prepare the GPG key space for a SIMP build.

          If passed anything but 'dev', will fail if the directory is not present in
          the 'build/build_keys' directory.

          ENV vars:
            - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :key_prep,[:key] do |t,args|
          require 'securerandom'
          _verbose = ENV.fetch('SIMP_PKG_verbose','no') == 'yes'

          args.with_defaults(:key => 'dev')

          Dir.chdir("#{@build_dir}/build_keys") {
            if (args.key != 'dev')
              fail("Could not find GPG keydir '#{args[:key]}' in '#{Dir.pwd}'") unless File.directory?(args[:key])
            end

            mkdir('dev') unless File.directory?('dev')
            chmod(0700,'dev')

            Dir.chdir('dev') {
              dev_email = 'gatekeeper@simp.development.key'
              current_key = `gpg --homedir=#{Dir.pwd} --list-keys #{dev_email} 2>/dev/null`
              days_left = 0
              if !current_key.empty?
                lasts_until = current_key.lines.first.strip.split("\s").last.delete(']')
                days_left = (Date.parse(lasts_until) - DateTime.now).to_i
              end

              if days_left > 0
                puts "GPG key will expire in #{days_left} days."
              else
                puts "Generating new GPG key"

                Dir.glob('*').each do |todel|
                  rm_rf(todel, :verbose => _verbose)
                end

                expire_date = (DateTime.now + 14)
                now = Time.now.to_i.to_s
                dev_email = 'gatekeeper@simp.development.key'
                passphrase = SecureRandom.base64(500)

                gpg_infile = <<-EOM
      %echo Generating Development GPG Key
      %echo
      %echo This key will expire on #{expire_date}
      %echo
      Key-Type: RSA
      Key-Length: 4096
      Key-Usage: sign
      Name-Real: SIMP Development
      Name-Comment: Development key #{now}
      Name-Email: #{dev_email}
      Expire-Date: 2w
      Passphrase: #{passphrase}
      %pubring pubring.gpg
      %secring secring.gpg
      # The following creates the key, so we can print "Done!" afterwards
      %commit
      %echo New GPG Development Key Created
                EOM

                gpg_agent_script = <<-EOM
      #!/bin/sh

      gpg-agent --homedir=#{Dir.pwd} --batch --daemon --pinentry-program /usr/bin/pinentry-curses < /dev/null &
                EOM

                File.open('gengpgkey','w'){ |fh| fh.puts(gpg_infile) }
                File.open('run_gpg_agent','w'){ |fh| fh.puts(gpg_agent_script) }
                chmod(0755,'run_gpg_agent')

                gpg_agent_pid = nil
                gpg_agent_socket = nil

                if File.exist?(%(#{ENV['HOME']}/.gnupg/S.gpg-agent))
                  gpg_agent_socket = %(#{ENV['HOME']}/.gnupg/S.gpg-agent)
                  gpg_agent_socket = %(#{ENV['HOME']}/.gnupg/S.gpg-agent)
                end

                begin
                  unless gpg_agent_socket
                    gpg_agent_output = %x(./run_gpg_agent).strip

                    if gpg_agent_output.empty?
                      # This is a working version of gpg-agent, that means we need to
                      # connect to it to figure out what's going on

                      gpg_agent_socket = %(#{Dir.pwd}/S.gpg-agent)
                      gpg_agent_pid_info = %x(gpg-agent --homedir=#{Dir.pwd} /get serverpid).strip
                      gpg_agent_pid_info =~ %r(\[(\d+)\])
                      gpg_agent_pid = $1
                    else
                      # Are we running a broken version of the gpg-agent? If so, we'll
                      # get back info on the command line.

                      gpg_agent_info = gpg_agent_output.split(';').first.split('=').last.split(':')
                      gpg_agent_socket = gpg_agent_info[0]
                      gpg_agent_pid = gpg_agent_info[1].strip.to_i

                      unless File.exist?(%(#{Dir.pwd}/#{File.basename(gpg_agent_socket)}))
                        ln_s(gpg_agent_socket,%(#{Dir.pwd}/#{File.basename(gpg_agent_socket)}))
                      end
                    end
                  end

                  sh %{gpg --homedir=#{Dir.pwd} --batch --gen-key gengpgkey}
                  sh %{gpg --homedir=#{Dir.pwd} --armor --export #{dev_email} > RPM-GPG-KEY-SIMP-Dev}
                ensure
                  begin
                    rm('S.gpg-agent') if File.symlink?('S.gpg-agent')

                    if gpg_agent_pid
                      Process.kill(0,gpg_agent_pid)
                      Process.kill(15,gpg_agent_pid)
                    end
                    rescue Errno::ESRCH
                    # Not Running, Nothing to do!
                  end
                end
              end
            }

            Dir.chdir(args[:key]) {
              rpm_build_keys = Dir.glob('RPM-GPG-KEY-*')
              target_dir = '../../GPGKEYS'

              fail("Could not find any RPM-GPG-KEY files in '#{Dir.pwd}'") if rpm_build_keys.empty?
              fail("No GPGKEYS directory at '#{Dir.pwd}/#{target_dir}") unless File.directory?(target_dir)

              dkfh = File.open("#{target_dir}/.dropped_keys",'w')

              rpm_build_keys.each do |gpgkey|
                cp(gpgkey,target_dir, :verbose => _verbose)
                dkfh.puts(gpgkey)
              end

              dkfh.flush
              dkfh.close
            }
          }
        end

        desc <<-EOM
          Build the entire SIMP release.

            Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
            * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).
            * :docs - Build the docs. Set this to false if you wish to skip building the docs.
            * :key - The GPG key to sign the RPMs with. Defaults to 'dev'.

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :build,[:chroot,:docs,:key,:snapshot_release] => [:prep,:mock_prep,:key_prep] do |t,args|
          validate_in_mock_group?
          _verbose = ENV.fetch('SIMP_PKG_verbose','no') == 'yes'

          args.with_defaults(:key => 'dev')
          args.with_defaults(:docs => 'true')

          output_dir = @pkg_dirs[:simp]

          check_dvd_env

          Rake::Task['pkg:simp_cli'].invoke(args[:chroot])
          Rake::Task['pkg:aux'].invoke(args[:chroot])
          if "#{args.docs}" == 'true'
            Rake::Task['pkg:doc'].invoke(args[:chroot])
          end
          Rake::Task['pkg:modules'].invoke(args[:chroot])

          # The main SIMP RPM must be built last!
          Rake::Task['pkg:simp'].invoke(args[:chroot],args[:snapshot_release])

          # Prepare for the build!
          rm_rf(output_dir, :verbose => _verbose)

          # Copy all the resulting files into the target output directory
          mkdir_p(output_dir)

          @build_dirs.each_pair do |k,dirs|
            Array(dirs).each do |dir|
              rpms = Dir.glob("#{dir}/dist/*.rpm")
              srpms = []
              rpms.delete_if{|x|
                del = false
                if x =~ /\.src\.rpm$/
                  del = true
                  srpms << x
                end

                del
              }

              srpms.each do |srpm|
                out_dir = "#{output_dir}/SRPMS"
                mkdir_p(out_dir, :verbose => _verbose) unless File.directory?(out_dir)

                unless uptodate?("#{out_dir}/#{File.basename(srpm)}",[srpm])
                  cp(srpm, out_dir, :verbose => _verbose)
                end
              end

              rpms.each do |rpm|
                out_dir = "#{output_dir}/RPMS/#{rpm.split('.')[-2]}"
                mkdir_p(out_dir, :verbose => _verbose) unless File.directory?(out_dir)

                unless uptodate?("#{out_dir}/#{File.basename(rpm)}",[rpm])
                  cp(rpm, out_dir, :verbose => _verbose)
                end
              end
            end
          end

          Rake::Task['pkg:signrpms'].invoke(args[:key])
        end

        desc <<-EOM
          Build the Puppet module RPMs.

            Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)

            * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).
            * :method - The Puppetfile from which the repository information should be read. Defaults to 'tracking'

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :modules,[:chroot,:method] => [:prep,:mock_prep] do |t,args|
          build(args[:chroot],@build_dirs[:modules],t)
        end

        desc <<-EOM
          Build a single Puppet Module RPM.

            Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)

            * :name   - The path, or name, of the module to build. If a name is
                        given, the Puppetfile.<method> will be used to find the
                        module.
                        Note: This is the *short* name. So, to build
                        puppetlabs-stdlib, you would just enter 'stdlib'
            * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).
            * :method - The Puppetfile from which the repository information should be read. Defaults to 'tracking'

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :single,[:name,:chroot,:method] => [:prep, :mock_prep] do |t,args|
          fail("You must pass :name to '#{t.name}'") unless args[:name]

          mod_path = File.absolute_path(args[:name])

          if args[:name].include?('/')
            fail("'#{args[:name]}' does not exist!") unless File.directory?(mod_path)
          else
            load_puppetfile(args[:method])
            local_module = puppetfile.modules.select{|m| m[:name] == args[:name]}.first

            unless local_module
              fail("'#{args[:name]}' was not found in the Puppetfile")
            end

            mod_path = local_module[:path]
          end

          ENV['SIMP_PKG_rand_name'] = 'yes'
          build(args[:chroot], Array(mod_path), t)

          puts("Your packages can be found in '#{mod_path}/dist'")
        end

        desc <<-EOM
          Build simp config rubygem RPM.

          * :method - The Puppetfile from which the repository information should be read. Defaults to 'tracking'

          ENV vars:
            - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :simp_cli,[:chroot] => [:prep,:mock_prep] do |t,args|
          build(args[:chroot], @build_dirs[:simp_cli], t)
        end

        desc <<-EOM
          Build the SIMP non-module RPMs.

            Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
            * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).
        EOM
        task :aux,[:chroot] => [:prep,:mock_prep]  do |t,args|
          build(args[:chroot],@build_dirs[:aux],t)
        end

        desc <<-EOM
          Build the SIMP documentation.

            Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
            * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :doc,[:chroot] => [:prep,:mock_prep] do |t,args|
          build(args[:chroot],@build_dirs[:doc],t)
        end

        desc <<-EOM
          Build the main SIMP RPM.

            Building this environment requires a working Mock setup (http://fedoraproject.org/wiki/Projects/Mock)
            * :chroot - The Mock chroot configuration to use. See the '--root' option in mock(1).
            * :snapshot_release - Will add a define to the Mock to set snapshot_release to current date and time.

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :simp,[:chroot,:snapshot_release] => [:prep,:mock_prep] do |t,args|
          build(args[:chroot],@build_dirs[:simp],t,false,args[:snapshot_release])
        end

        desc "Sign the RPMs."
        task :signrpms,[:key,:rpm_dir,:force] => [:prep,:key_prep,:mock_prep] do |t,args|
          which('rpmsign') || raise(Exception, 'Could not find rpmsign on your system. Exiting.')

          args.with_defaults(:key => 'dev')
          args.with_defaults(:rpm_dir => "#{@build_dir}/SIMP/*RPMS")
          args.with_default(:force => 'false')

          force = (args[:force].to_s == 'false' ? false : true)

          rpm_dirs = Dir.glob(args[:rpm_dir])
          to_sign = []

          rpm_dirs.each do |rpm_dir|
            Find.find(rpm_dir) do |rpm|
              next unless File.readable?(rpm)
              to_sign << rpm if rpm =~ /\.rpm$/
            end
          end

          Parallel.map(
            to_sign,
            :in_processes => get_cpu_limit,
            :progress => t.name
          ) do |rpm|
            rpminfo = %x{rpm -qip #{rpm} 2>/dev/null}.split("\n")
            if (force || !rpminfo.grep(/Signature\s+:\s+\(none\)/).empty?)
              Simp::RPM.signrpm(rpm,"#{@build_dir}/build_keys/#{args[:key]}")
            end
          end
        end

        desc <<-EOM
          Check that RPMs are signed.

            Checks all RPM files in a directory to see if they are trusted.
              * :rpm_dir - A directory containing RPM files to check. Default #{@build_dir}/SIMP
              * :key_dir - The path to the GPG keys you want to check the packages against. Default #{@build_dir}/GPGKEYS
        EOM
        task :checksig,[:rpm_dir,:key_dir] => [:prep] do |t,args|
          begin
            args.with_defaults(:rpm_dir => @pkg_dirs[:ext])
            args.with_defaults(:key_dir => "#{@build_dir}/GPGKEYS")

            rpm_dirs = Dir.glob(args[:rpm_dir])

            fail("Could not find files at #{args[:rpm_dir]}!") if rpm_dirs.empty?

            temp_gpg_dir = Dir.mktmpdir

            rpm_cmd = %{rpm --dbpath #{temp_gpg_dir}}

            sh %{#{rpm_cmd} --initdb}

            # Only import thngs that look like GPG keys...
            Dir.glob("#{args[:key_dir]}/*").each do |key|
              next if File.directory?(key) or not File.readable?(key)

              File.read(key).each_line do |line|
                if line =~ /-----BEGIN PGP PUBLIC KEY BLOCK-----/
                  sh %{#{rpm_cmd} --import #{key}}
                  break
                end
              end
            end

            bad_rpms = []
            rpm_dirs.each do |rpm_dir|
              Find.find(rpm_dir) do |path|
                if (path =~ /.*\.rpm$/)
                  result = %x{#{rpm_cmd} --checksig #{path}}.strip
                  if result !~ /:.*\(\S+\).* OK$/
                    bad_rpms << path.split(/\s/).first
                  end
                end
              end
            end

            if !bad_rpms.empty?
              bad_rpms.map!{|x| x = "  * #{x}"}
              bad_rpms.unshift("ERROR: Untrusted RPMs found in the repository:")

              fail(bad_rpms.join("\n"))
            else
              puts "Checksig succeeded"
            end
          ensure
            remove_entry_secure temp_gpg_dir
          end
        end

        desc <<-EOM
          Run repoclosure on RPM files.

            Finds all rpm files in the target dir and all of its subdirectories, then
            reports which packages have unresolved dependencies. This needs to be run
            after rake tasks tar:build and unpack if operating on the base SIMP repo.
              * :target_dir  - The directory to assess. Default #{@build_dir}/SIMP.
              * :aux_dir     - Auxillary repo glob to use when assessing. Default #{@build_dir}/Ext_*.
                              Defaults to ''(empty) if :target_dir is not the system default.

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
              - Set `SIMP_PKG_repoclose_pe=yes` to enable repoclosure on PE-related RPMs.

        EOM
        task :repoclosure,[:target_dir,:aux_dir] => [:prep] do |t,args|
          default_target = @pkg_dirs[:simp]
          args.with_defaults(:target_dir => default_target)
          if args[:target_dir] == default_target
            args.with_defaults(:aux_dir => @pkg_dirs[:ext])
          else
            args.with_defaults(:aux_dir => '')
          end

          _verbose = ENV.fetch('SIMP_PKG_verbose','no') == 'yes'
          _repoclose_pe = ENV.fetch('SIMP_PKG_repoclose_pe','no') == 'yes'

          yum_conf_template = <<-EOF
[main]
keepcache=0
exactarch=1
obsoletes=1
gpgcheck=0
plugins=1
installonly_limit=5
<% unless #{_repoclose_pe} -%>
exclude=*-pe-*
<% end -%>

<% repo_files.each do |repo| -%>
include=file://<%= repo %>
<% end -%>
  EOF

          yum_repo_template = <<-EOF
[<%= repo_name %>]
name=<%= repo_name %>
baseurl=file://<%= repo_path %>
enabled=1
gpgcheck=0
protect=1
  EOF

          fail("#{args[:target_dir]} does not exist!") unless File.directory?(args[:target_dir])

          begin
            temp_pkg_dir = Dir.mktmpdir

            mkdir_p("#{temp_pkg_dir}/repos/base")
            mkdir_p("#{temp_pkg_dir}/repos/lookaside")
            mkdir_p("#{temp_pkg_dir}/repodata")

            Dir.glob(args[:target_dir]).each do |base_dir|
              Find.find(base_dir) do |path|
                if (path =~ /.*\.rpm$/) and (path !~ /.*.src\.rpm$/)
                  sym_path = "#{temp_pkg_dir}/repos/base/#{File.basename(path)}"
                  ln_s(path,sym_path, :verbose => _verbose) unless File.exists?(sym_path)
                end
              end
            end

            Dir.glob(args[:aux_dir]).each do |aux_dir|
              Find.find(aux_dir) do |path|
                if (path =~ /.*\.rpm$/) and (path !~ /.*.src\.rpm$/)
                  sym_path = "#{temp_pkg_dir}/repos/lookaside/#{File.basename(path)}"
                  ln_s(path,sym_path, :verbose => _verbose) unless File.exists?(sym_path)
                end
              end
            end

            Dir.chdir(temp_pkg_dir) do
              repo_files = []
              Dir.glob('repos/*').each do |repo|
                if File.directory?(repo)
                  Dir.chdir(repo) { sh %{createrepo .} }

                  repo_name = File.basename(repo)
                  repo_path = File.expand_path(repo)
                  conf_file = "#{temp_pkg_dir}/#{repo_name}.conf"

                  File.open(conf_file,'w') do |file|
                    file.write(ERB.new(yum_repo_template,nil,'-').result(binding))
                  end

                  repo_files << conf_file
                end
              end

              File.open('yum.conf', 'w') do |file|
                file.write(ERB.new(yum_conf_template,nil,'-').result(binding))
              end

              cmd = 'repoclosure -c repodata -n -t -r base -l lookaside -c yum.conf'

              if ENV['SIMP_BUILD_verbose'] == 'yes'
                puts
                puts '-'*80
                puts "#### RUNNING: `#{cmd}`"
                puts "     in path '#{Dir.pwd}'"
                puts '-'*80
              end
              repoclosure_output = %x(#{cmd})

              if (!$?.success? || (repoclosure_output =~ /nresolved/))
                errmsg = ['Error: REPOCLOSURE FAILED:']
                errmsg << [repoclosure_output]
                fail(errmsg.join("\n"))
              end
            end
          ensure
            remove_entry_secure temp_pkg_dir
          end
        end

        ##############################################################################
        # Helper methods
        ##############################################################################

        # Takes a list of directories to hop into and perform builds within
        # Needs to be passed the chroot path as well
        #
        # The task must be passed so that we can output the calling name in the
        # status bar.
        def build(chroot,dirs,task,add_to_autoreq=true,snapshot_release=false)
          validate_in_mock_group?
          _verbose = ENV.fetch('SIMP_PKG_verbose','no') == 'yes'

          # Default package metadata for reference
          default_metadata = YAML.load(File.read("#{@src_dir}/build/package_metadata_defaults.yaml"))

          reenable_lock = Mutex.new

          metadata = Parallel.map(
            # Allow for shell globs
            Array(dirs),
            :in_processes => get_cpu_limit,
            :progress => task.name
          ) do |dir|
            result = []

            fail("Could not find directory #{dir}") unless Dir.exist?(dir)

            Dir.chdir(dir) do
              built_rpm = false
              unique_build = (get_cpu_limit != 1).to_s

              if _verbose
                $stderr.puts("Running 'rake pkg:rpm' on #{File.basename(dir)}")
              end

              # We're building a module, override anything down there
              if File.exist?('metadata.json')
                unique_namespace = (0...24).map{ (65 + rand(26)).chr }.join.downcase

                Simp::Rake::Pkg.new(Dir.pwd, nil, unique_namespace, @simp_version)

                Rake::Task["#{unique_namespace}:pkg:rpm"].invoke(chroot, unique_build, snapshot_release)

                built_rpm = true

              # We're building one of the extra assets and should honor its Rakefile
              elsif File.exist?('Rakefile')

                rake_flags = Rake.application.options.trace ? '--trace' : ''

                cmd = %{SIMP_BUILD_version=#{@simp_version} rake pkg:rpm[#{chroot},#{unique_build},#{snapshot_release}] #{rake_flags} 2>&1}

                build_success = true
                begin
                  ::Bundler.with_clean_env do
                    %x{#{cmd}}
                    build_success = $?.success?
                  end

                  built_rpm = true
                rescue
                  build_success = false
                end

                unless build_success
                  if _verbose
                    $stderr.puts("First 'rake pkg:rpm' attempt failed, running bundle and trying again.")
                  end

                  ::Bundler.with_clean_env do
                    %x{bundle install --with development}
                    %x{#{cmd}}
                  end
                end
              else
                puts "Warning: '#{dir}' could not be built via Rake"
              end

              if built_rpm
                tarballs = Dir.glob('dist/*.tar.gz')
                srpms = Dir.glob('dist/*.src.rpm')
                rpms = (Dir.glob('dist/*.rpm') - srpms)

                # Not all items generate tarballs
                tarballs.each do |pkg|
                  if (File.stat(pkg).size == 0)
                    raise("Empty Tarball '#{pkg}' generated for #{dir}")
                  end
                end
                raise("No SRPMs generated for #{dir}") if srpms.empty?
                raise("No RPMs generated for #{dir}") if rpms.empty?

                # Glob all generated rpms, and add their metadata to a result array.
                rpms.each do |rpm|
                  # get_info from each generated rpm, not the spec file, so macros in the
                  # metadata have already been resolved in the mock chroot.
                  metadata = Simp::RPM.get_info(rpm)

                  if File.exist?('build/package_metadata.yaml')
                    metadata.merge!(YAML.load_file('build/package_metadata.yaml'))
                  end

                  result << metadata
                end
              end

              if _verbose
                $stderr.puts("Finshed 'rake pkg:rpm' on #{File.basename(dir)}")
              end
            end

            result
          end

          metadata.each do |mod|
            # Each module could generate multiple rpms, each with its own metadata.
            # Iterate over them to add all built rpms to autorequires.
            mod.each do |module_pkginfo|
              next unless (module_pkginfo && module_pkginfo.is_a?(Hash))

              # Set up the autorequires
              if add_to_autoreq
                # Register the package with the autorequires
                mode = 'r+'
                mode = 'w+' unless File.exist?("#{@src_dir}/build/autorequires")
                autoreq_fh = File.open("#{@src_dir}/build/autorequires",mode)

                begin
                  # Reads the autorequires file, then empties it
                  autorequires = []
                  autorequires += autoreq_fh.read.split("\n")
                  autoreq_fh.rewind
                  autoreq_fh.truncate(0)

                  # The SIMP Rakefile expects the autorequires to be in this format.
                  autorequires << "#{module_pkginfo[:name]} #{module_pkginfo[:version]} #{module_pkginfo[:release]}"
                  autoreq_fh.puts(autorequires.sort.uniq.join("\n"))
                ensure
                  autoreq_fh.flush
                  autoreq_fh.close
                end
              end
            end
          end
        end

        #desc "Checks the environment for building the DVD tarball
        def check_dvd_env
          ["#{@dvd_src}/isolinux","#{@dvd_src}/ks"].each do |dir|
            File.directory?(dir)or raise "Environment not suitable: Unable to find directory '#{dir}'"
          end
        end

        # Return an Array of all puppet module directories
        def get_module_dirs(method='tracking')
          load_puppetfile(method)
          module_paths.select{|x| File.basename(File.dirname(x)) == 'modules'}.sort
        end
      end
    end
  end
end
