# frozen_string_literal: true

require 'rake/tasklib'

module Simp; end

class Simp::Rake::Fixtures < Rake::TaskLib
  def initialize(dir)
    @base_dir = dir
    # ##::CLEAN.include( '.fixtures.yml.local' )
    define
  end

  def define
    namespace :fixtures do
      def flatten_fixtures_hash(_f)
        _f
          .map { |_k, v| v.values }
          .flatten
          .each_with_object({}) { |pairs, h|
            pairs.each do |k, v|
              (h[k] ||= []) << v
            end
          }
          .keys
          .uniq
          .sort
      end

      def fixtures_yml_local(_f)
        _f_m = flatten_fixtures_hash(_f)

        _s = _f_m.to_h do |k|
          v = _f['fixtures']['repositories'].key?(k) ? "#\{source_dir}/../#{k}" : _f['fixtures']['symlinks'].fetch(k)
          [k, v]
        end

        { 'fixtures' => { 'symlinks' => _s } }
      end

      desc 'generate .fixtures.yml.local formm the entries in .fixtures.yml'
      task :generate do
        pwd = File.expand_path(@base_dir)
        _f  = YAML.load_file(File.join(pwd, '.fixtures.yml'))
        _l  = clean_yaml(fixtures_yml_local(_f).to_yaml)
        _o  = File.join(pwd, '.fixtures.yml.local')
        File.open(_o, 'w') do |f|
          puts _l
          f.puts _l
        end
        puts
        puts "# written to '#{_o}'"
      end

      desc 'check for missing .fixture modules'
      task :diff do
        require 'yaml'
        pwd = File.expand_path(@base_dir)
        _f  = YAML.load_file(File.join(pwd, '.fixtures.yml'))

        unless File.file?(File.join(pwd, '.fixtures.yml.local'))
          raise "ERROR: Can't diff fixtures without a `.fixtures.yml.local` file"
        end

        _fl = YAML.load_file(File.join(pwd, '.fixtures.yml.local'))

        # reduce modules
        _f_m  = flatten_fixtures_hash(_f)
        _fl_m = flatten_fixtures_hash(_fl)
        _f_u  = (_f_m - _fl_m)
        _fl_u = (_fl_m - _f_m)

        if (_f_u.size + _fl_u.size).positive?
          warn ''
          warn 'WARNING: .fixtures.yml & .fixtures.yml.local have different files!'
          warn ''
          if _f_u.size.positive?
            warn 'Unique modules to .fixtures.yml:'
            _f_u.each { |x| warn "  - #{x}" }
            warn ''
          end
          if _fl_u.size.positive?
            warn 'Unique modules to .fixtures.yml.local:'
            _fl_u.each { |x| warn "  - #{x}" }
            warn ''
          end
          exit 1
        end
      end
    end
  end
end
