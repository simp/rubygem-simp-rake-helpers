require 'yaml'
require 'json'

# A cowardly Heap merge that only overwrites keys that already exist
def creep_merge( j, o )
  result = nil
  if o.is_a? Hash
     o.keys.each do |k|
      puts "== k: #{k} | #{k.class} | j: #{j.class}" if ENV['VERBOSE'] == 'yes'
      if j.is_a?(Hash)
        unless  j.key?(k)
          warn "!!!!!!!!!  WARNING NO key '#{k}'"
          if ENV['PRY'] == 'yes'
            require 'pry'
            binding.pry
          end
        else
          j[k] = creep_merge(j[k], o[k])
        end
      else
        j = o[k]
      end
      result = j
    end
  else
    result = o
  end
  result
end

def scrub_data(f)
  _ff = File.basename(f).sub(/\.facts/,'.scrub.yaml')
  ff = File.expand_path( "gce_scrub_data/#{_ff}", File.dirname(__FILE__))
  scrub = YAML.load_file ff
  data = JSON.parse(File.read(f))
  ff =  "#{f}.yaml"
  File.open(ff,'w'){|fd| fd.puts data.to_yaml }
  fb = f.sub(/.facts$/,'.facts.bak')
  unless File.exists? fb
    File.open(fb,'w'){|fd| fd.puts data}
    warn "== wrote '#{fb}'"
  end
  warn "== wrote '#{ff}'"
  scrubbed_data = creep_merge( data, scrub )
  scrubbed_data.fetch('gce',{}).fetch('project',{}).fetch('attributes',{}).fetch('sshKeys',[]).delete_if{|x| x =~ /chris_tessmer/}
  File.open(f,'w'){|fd| fd.puts JSON.pretty_generate(scrubbed_data)}
  warn "== wrote '#{f}'"
end

ARGV.each do |file|
  scrub_data(file)
end
