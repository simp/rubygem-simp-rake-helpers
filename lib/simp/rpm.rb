rb_files = File.expand_path( 'rpm/*.rb', File.dirname(__FILE__))
Dir.glob( rb_files ).sort_by(&:to_s).each { |file| require file }

