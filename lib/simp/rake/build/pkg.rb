#!/usr/bin/rake -T

require 'simp/yum'
require 'simp/rake/pkg'
require 'simp/rake/build/constants'
require 'simp/rake/build/rpmdeps'

module Simp; end
module Simp::Rake; end
module Simp::Rake::Build

  class Pkg < ::Rake::TaskLib
    include Simp::Rake
    include Simp::Rake::Build::Constants

    def initialize( base_dir )
      init_member_vars( base_dir )

      @verbose = ENV.fetch('SIMP_PKG_verbose','no') == 'yes'

      define_tasks
    end

    def define_tasks
      namespace :pkg do
        ##############################################################################
        # Main tasks
        ##############################################################################

        # Have to get things set up inside the proper namespace
        task :prep,[:method] do |t,args|

          # This doesn't get caught for things like 'rake clean'
          if $simp6 && $simp6_build_dir
            @build_dir = $simp6_build_dir
            @dvd_src = File.join(@build_dir, File.basename(@dvd_src))
          end

          args.with_defaults(:method => 'tracking')

          @build_dirs = {
            :modules => get_module_dirs(args[:method]),
            :aux => [
              # Anything in here gets built!
              "#{@src_dir}/assets/*"
            ],
            :doc => "#{@src_dir}/doc"
          }

          @build_dirs[:aux].map!{|dir| dir = Dir.glob(dir)}
          @build_dirs[:aux].flatten!
          @build_dirs[:aux].delete_if{|f| !File.directory?(f)}

          @pkg_dirs = {
            :simp => "#{@build_dir}/SIMP"
          }
        end

        clean_failures = []
        clean_failures_lock = Mutex.new

        task :clean => [:prep] do |t,args|
          @build_dirs.each_pair do |k,dirs|
            Parallel.map(
              Array(dirs),
              :in_processes => get_cpu_limit,
              :progress => t.name
            ) do |dir|
              Dir.chdir(dir) do
                begin
                  rake_flags = Rake.application.options.trace ? '--trace' : ''
                  %x{rake clean #{rake_flags}}
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
        end

        task :clobber => [:prep] do |t,args|
          @build_dirs.each_pair do |k,dirs|
            Parallel.map(
              Array(dirs),
              :in_processes => get_cpu_limit,
              :progress => t.name
            ) do |dir|
              Dir.chdir(dir) do
                rake_flags = Rake.application.options.trace ? '--trace' : ''
                sh %{rake clobber #{rake_flags}}
              end
            end
          end
        end

=begin
        desc <<-EOM
          Prepare the GPG key space for a SIMP build.

          If passed anything but 'dev', will fail if the directory is not present in
          the 'build/build_keys' directory.

          ENV vars:
            - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
=end
        task :key_prep,[:key] => [:prep] do |t,args|
          require 'securerandom'
          _verbose = ENV.fetch('SIMP_PKG_verbose','no') == 'yes'

          args.with_defaults(:key => 'dev')

          FileUtils.mkdir_p("#{@build_dir}/build_keys")

          Dir.chdir("#{@build_dir}/build_keys") do
            if (args.key != 'dev')
              fail("Could not find GPG keydir '#{args[:key]}' in '#{Dir.pwd}'") unless File.directory?(args[:key])
            else

              mkdir('dev') unless File.directory?('dev')
              chmod(0700,'dev')

              Dir.chdir('dev') do
                dev_email = 'gatekeeper@simp.development.key'
                current_key = `gpg --homedir=#{Dir.pwd} --list-keys #{dev_email} 2>/dev/null`
                days_left = 0
                unless current_key.empty?
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
                    %x{gpg --homedir=#{Dir.pwd} --armor --export #{dev_email} > RPM-GPG-KEY-SIMP-Dev}
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
              end
            end

            Dir.chdir(args[:key]) do
              rpm_build_keys = Dir.glob('RPM-GPG-KEY-*')

              fail("Could not find any RPM-GPG-KEY files in '#{Dir.pwd}'") if rpm_build_keys.empty?

              # Drop the development key in the root of the ISO for convenience
              if args[:key] == 'dev'
                target_dir = @dvd_src

                fail("Could not find directory '#{target_dir}'") unless File.directory?(target_dir)

                rpm_build_keys.each do |gpgkey|
                  cp(gpgkey,target_dir, :verbose => _verbose)
                end
              # Otherwise, make sure it isn't present for the build
              else
                Dir.glob(File.join(@dvd_src,'RPM-GPG-KEY-SIMP*')).each do |to_del|
                  rm(to_del)
                end
              end
            end
          end
        end

        def populate_rpm_dir(rpm_dir)
          srpm_dir = File.join(File.dirname(rpm_dir), 'SRPMS')

          FileUtils.mkdir_p(rpm_dir)
          FileUtils.mkdir_p(srpm_dir)

          rpm_metadata_filename = 'last_rpm_build_metadata.yaml'
          rpm_metadata = %x(find -P #{@src_dir} -xdev -type f -name #{rpm_metadata_filename}).lines.map(&:strip).sort

          fail("No #{rpm_metadata_filename} files found under #{@src_dir}") if rpm_metadata.empty?

          rpm_metadata.each do |mf|
            metadata = YAML.load_file(mf)
            rpms = metadata['rpms']
            srpms = metadata['srpms']

            fail("No RPMs found at #{rpm_dir}") if (rpms.nil? || rpms.empty?)

            have_signed_rpm = false

            Dir.chdir(rpm_dir) do
              rpms.each_key do |rpm|
                if @verbose
                  puts "Copying #{rpm} to #{rpm_dir}"
                end

                arch = rpms[rpm]['metadata'][:arch]
                FileUtils.mkdir_p(arch)

                FileUtils.cp(rpms[rpm]['path'], arch)

                if rpms[rpm][:signature]
                  have_signed_rpm = true
                end
              end
            end

            Dir.chdir(srpm_dir) do
              srpms.each_key do |srpm|
                if have_signed_rpm && !srpms[srpm][:signature]
                  if @verbose
                    puts "Found signed RPM - skipping copy of '#{srpm}'"
                  end

                  next
                end

                if @verbose
                  puts "Copying '#{srpm}' to '#{srpm_dir}'"
                end

                arch = srpms[srpm]['metadata'][:arch]
                FileUtils.mkdir_p(arch)

                FileUtils.cp(srpms[srpm]['path'], arch)
              end
            end
          end
        end


=begin
        desc <<-EOM
          Build the entire SIMP release.

            * :docs - Build the docs. Set this to false if you wish to skip building the docs.
            * :key - The GPG key to sign the RPMs with. Defaults to 'dev'.

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
=end
        task :build,[:docs,:key] => [:prep,:key_prep] do |t,args|

          _verbose = ENV.fetch('SIMP_PKG_verbose','no') == 'yes'

          args.with_defaults(:key => 'dev')
          args.with_defaults(:docs => 'true')

          check_dvd_env

          Rake::Task['pkg:aux'].invoke
          if "#{args.docs}" == 'true'
            Rake::Task['pkg:doc'].invoke
          end
          Rake::Task['pkg:modules'].invoke

          populate_rpm_dir(@rpm_dir)

          Rake::Task['pkg:signrpms'].invoke(args[:key])
        end

        desc <<-EOM
          Build the Puppet module RPMs.

            * :method - The Puppetfile from which the repository information
                        should be read. Defaults to 'tracking'

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :modules,[:method] => [:prep] do |t,args|
          build(@build_dirs[:modules],t)
        end

        desc <<-EOM
          Build a single Puppet Module RPM.

            * :name   - The path, or name, of the module to build. If a name is
                        given, the Puppetfile.<method> will be used to find the
                        module.
                        Note: This is the *short* name. So, to build
                        puppetlabs-stdlib, you would just enter 'stdlib'
            * :method - The Puppetfile from which the repository information should be read. Defaults to 'tracking'

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :single,[:name,:method] => [:prep] do |t,args|
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
          build(Array(mod_path), t)

          puts("Your packages can be found in '#{mod_path}/dist'")
        end

        desc <<-EOM
          Build the SIMP non-module RPMs.

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :aux => [:prep]  do |t,args|
          build(@build_dirs[:aux],t)
        end

        desc <<-EOM
          Build the SIMP documentation.

            ENV vars:
              - Set `SIMP_PKG_verbose=yes` to report file operations as they happen.
        EOM
        task :doc => [:prep] do |t,args|
          build(@build_dirs[:doc],t)
        end

        desc "Sign the RPMs."
        task :signrpms,[:key,:rpm_dir,:force] => [:prep,:key_prep] do |t,args|
          which('rpmsign') || raise(StandardError, 'Could not find rpmsign on your system. Exiting.')

          args.with_defaults(:key => 'dev')
          args.with_defaults(:rpm_dir => File.join(File.dirname(@rpm_dir), '*RPMS'))
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
            rpm_info = Simp::RPM.new(rpm)
            Simp::RPM.signrpm(rpm, "#{@build_dir}/build_keys/#{args[:key]}") unless rpm_info.signature
          end
        end

=begin
        desc <<-EOM
          Check that RPMs are signed.

            Checks all RPM files in a directory to see if they are trusted.
              * :rpm_dir - A directory containing RPM files to check. Default #{@build_dir}/SIMP
              * :key_dir - The path to the GPG keys you want to check the packages against. Default #{@src_dir}/assets/simp-gpgkeys/
        EOM
=end
        task :checksig,[:rpm_dir,:key_dir] => [:prep] do |t,args|
          begin
            args.with_defaults(:rpm_dir => @pkg_dirs[:simp])
            args.with_defaults(:key_dir => "#{@src_dir}/assets/simp-gpgkeys")

            rpm_dirs = Dir.glob(args[:rpm_dir])

            fail("Could not find files at #{args[:rpm_dir]}!") if rpm_dirs.empty?

            temp_gpg_dir = Dir.mktmpdir
            at_exit { FileUtils.remove_entry(temp_gpg_dir) if File.exist?(temp_gpg_dir) }

            rpm_cmd = %{rpm --dbpath #{temp_gpg_dir}}

            %x{#{rpm_cmd} --initdb}

            public_keys = Dir.glob(File.join(args[:key_dir], '*'))
            public_keys += Dir.glob(File.join(@build_dir, 'build_keys', '*', 'RPM-GPG-KEY*'))
            public_keys += Array(@gpg_keys)

            # Only import thngs that look like GPG keys...
            public_keys.each do |key|
              next if File.directory?(key) or !File.readable?(key)

              File.read(key).each_line do |line|
                if line =~ /-----BEGIN PGP PUBLIC KEY BLOCK-----/
                  %x{#{rpm_cmd} --import #{key}}
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

            unless bad_rpms.empty?
              bad_rpms.map!{|x| x = "  * #{x}"}
              bad_rpms.unshift("ERROR: Untrusted RPMs found in the repository:")

              fail(bad_rpms.join("\n"))
            else
              puts "Checksig succeeded"
            end
          ensure
            remove_entry_secure temp_gpg_dir if (temp_gpg_dir && File.exist?(temp_gpg_dir))
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
          args.with_defaults(:target_dir => File.expand_path(default_target))

          if args[:aux_dir]
            args[:aux_dir] = File.expand_path(args[:aux_dir])
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

          Dir.mktmpdir do |temp_pkg_dir|
            Dir.chdir(temp_pkg_dir) do
              mkdir_p('repos/base')
              mkdir_p('repos/lookaside')
              mkdir_p('repodata')

              Dir.glob(args[:target_dir]).each do |base_dir|
                Find.find(base_dir) do |path|
                  if (path =~ /.*\.rpm$/) and (path !~ /.*.src\.rpm$/)
                    sym_path = "repos/base/#{File.basename(path)}"
                    ln_s(path,sym_path, :verbose => _verbose) unless File.exists?(sym_path)
                  end
                end
              end

              if args[:aux_dir]
                Dir.glob(args[:aux_dir]).each do |aux_dir|
                  Find.find(aux_dir) do |path|
                    if (path =~ /.*\.rpm$/) and (path !~ /.*.src\.rpm$/)
                      sym_path = "repos/lookaside/#{File.basename(path)}"
                      ln_s(path,sym_path, :verbose => _verbose) unless File.exists?(sym_path)
                    end
                  end
                end
              end

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
          end
        end

        ##############################################################################
        # Helper methods
        ##############################################################################

        # Takes a list of directories to hop into and perform builds within
        #
        # The task must be passed so that we can output the calling name in the
        # status bar.
        def build(dirs,task,add_to_autoreq=true)
          _verbose = ENV.fetch('SIMP_PKG_verbose','no') == 'yes'

          rpm_dependency_file = File.join(@base_dir, 'build', 'rpm', 'dependencies.yaml')

          if File.exist?(rpm_dependency_file)
            rpm_metadata = YAML.load(File.read(rpm_dependency_file))
          end

          Parallel.map(
            # Allow for shell globs
            Array(dirs),
            :in_processes => get_cpu_limit,
            :progress => task.name
          ) do |dir|
            fail("Could not find directory #{dir}") unless Dir.exist?(dir)

            Dir.chdir(dir) do
              built_rpm = false

              if _verbose
                $stderr.puts("Running 'rake pkg:rpm' on #{File.basename(dir)}")
              end

              # We're building a module, override anything down there
              if File.exist?('metadata.json')

                # Generate RPM metadata files
                # - 'build/rpm_metadata/requires' file containing RPM
                #   dependency/obsoletes information from the
                #   'dependencies.yaml' and the module's
                #   'metadata.json'; always created
                # - 'build/rpm_metadata/release' file containing RPM
                #   release qualifier from the 'dependencies.yaml';
                #   only created if release qualifier if specified in
                #   the 'dependencies.yaml'
                Simp::Rake::Build::RpmDeps::generate_rpm_meta_files(dir, rpm_metadata)

                # This allows us to properly handle parallelization of all of
                # the Rake task calls
                unique_namespace = (0...24).map{ (65 + rand(26)).chr }.join.downcase

                new_rpm = Simp::Rake::Pkg.new(Dir.pwd, unique_namespace, @simp_version)

                new_rpm_info = Simp::RPM.new(new_rpm.spec_file)

                # Pull down any newer versions of the target RPM if we've been
                # given a source yum configuration
                #
                # Just build from scratch if something goes wrong
                begin
                  yum_helper = Simp::YUM.new(
                    Simp::YUM.generate_yum_conf(File.join(@distro_build_dir, 'yum_data')))
                rescue Simp::YUM::Error
                end

                if yum_helper
                  new_rpm_info.packages.map{|x| x = File.basename(x, '.rpm')}.each do |new_rpm|
                    begin
                      published_rpm = yum_helper.available_package(new_rpm)

                      if published_rpm
                        unless new_rpm_info.newer?(published_rpm)
                          yum_helper.download("#{new_rpm}", :target_dir => 'dist')
                          $stderr.puts "Found newer remote RPM for #{new_rpm}" if @verbose
                        end
                      end
                    rescue Simp::YUM::Error => e
                      $stderr.puts e if @verbose
                    end
                  end
                end

                Rake::Task["#{unique_namespace}:pkg:rpm"].invoke

                built_rpm = true

              # We're building one of the extra assets and should honor its Rakefile
              elsif File.exist?('Rakefile')

                rake_flags = Rake.application.options.trace ? '--trace' : ''

                cmd = %{SIMP_BUILD_version=#{@simp_version} rake pkg:rpm #{rake_flags} 2>&1}

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
                    output = %x{#{cmd} 2>&1}

                    unless $?.success?
                      raise("Error running #{cmd}\n#{output}")
                    end
                  end
                end
              else
                puts "Warning: '#{dir}' could not be built via Rake"
              end

              if built_rpm
                tarballs = Dir.glob('dist/*.tar.gz')
                rpms = Dir.glob('dist/*.rpm').delete_if{|x| x =~ %r(\.src\.rpm$)}

                # Not all items generate tarballs
                tarballs.each do |pkg|
                  if (File.stat(pkg).size == 0)
                    raise("Empty Tarball '#{pkg}' generated for #{dir}")
                  end
                end

                raise("No RPMs generated for #{dir}") if rpms.empty?
              end

              if _verbose
                $stderr.puts("Finshed 'rake pkg:rpm' on #{File.basename(dir)}")
              end
            end
          end
        end

        #desc "Checks the environment for building the DVD tarball
        def check_dvd_env
          ["#{@dvd_src}/isolinux","#{@dvd_src}/ks"].each do |dir|
            File.directory?(dir) or raise "Environment not suitable: Unable to find directory '#{dir}'"
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
