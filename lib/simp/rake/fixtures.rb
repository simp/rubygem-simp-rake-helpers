require 'rake/tasklib'
require 'simp'

module Simp; end
module Simp::Rake
  class Fixtures < ::Rake::TaskLib
    attr_reader :log

    def initialize( dir )
       @base_dir = dir
       @log      = Logging.logger[self]
       ###::CLEAN.include( '.fixtures.yml.local' )
       define
    end

    def define
      namespace :fixtures do
        def flatten_fixtures_hash(_f)
          _f
            .map{|k,v| v.values}
            .flatten
            .reduce({}){|h,pairs|
              pairs.each{|k,v|
                (h[k] ||= []) << v
              }; h
            }
            .keys
            .uniq
            .sort
        end

        def fixtures_yml_local(_f)
          _f_m  = flatten_fixtures_hash(_f)

          _s = Hash[_f_m.map{|k|
            v= _f['fixtures']['repositories'].key?(k) ? "#\{source_dir\}/../#{k}": _f['fixtures']['symlinks'].fetch(k)
            [k, v ]}
          ]

          {'fixtures'=> {'symlinks'=> _s }}
        end

        desc 'generate .fixtures.yml.local formm the entries in .fixtures.yml'
        task :generate do
          pwd = File.expand_path(@base_dir)
          _f  = YAML.load_file(File.join(pwd,'.fixtures.yml'))
          _l  = fixtures_yml_local( _f )
          _o  = File.join(pwd,'.fixtures.yml.local')
          File.open( _o,'w'){|f| puts _l.to_yaml; f.puts _l.to_yaml}
          puts
          puts "# written to '#{_o}'"
        end


        desc "check for missing .fixture modules"
        task :diff do
          require 'yaml'
          pwd = File.expand_path(@base_dir)
          _f  = YAML.load_file(File.join(pwd,'.fixtures.yml'))
          
          unless File.file?(File.join(pwd,'.fixtures.yml.local'))
            fail "ERROR: Can't diff fixtures without a `.fixtures.yml.local` file"
          end

          _fl = YAML.load_file(File.join(pwd,'.fixtures.yml.local'))

          # reduce modules
          _f_m  = flatten_fixtures_hash(_f)
          _fl_m = flatten_fixtures_hash(_fl)
          _f_u  = (_f_m-_fl_m)
          _fl_u = (_fl_m-_f_m)

          if (_f_u.size + _fl_u.size) > 0
            warn ''
            warn "WARNING: .fixtures.yml & .fixtures.yml.local have different files!"
            warn ''
            if _f_u.size > 0
              warn 'Unique modules to .fixtures.yml:'
              _f_u.each{|x| warn "  - #{x}"}
              warn ''
            end
            if _fl_u.size > 0
              warn 'Unique modules to .fixtures.yml.local:'
              _fl_u.each{|x| warn "  - #{x}"}
              warn ''
            end
            exit 1
          end
        end
      end
    end
  end
end
