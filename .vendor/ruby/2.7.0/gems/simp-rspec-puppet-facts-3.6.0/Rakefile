require 'simp/rake/beaker'
require 'bundler/gem_tasks'

Simp::Rake::Beaker.new(__dir__)

namespace :syntax do
  def syntax_check(task, glob)
    warn "---> #{task.name}"
    Dir.glob(glob).map do |file|
      puts '------| Attempting to load: ' + file
      yield(file)
    end
  end

  desc 'Syntax check for facts files under facts/'
  task :facts do |t|
    require 'json'
    syntax_check(t, 'facts/**/*.facts') { |j| JSON.parse(File.read(j)) }
  end
end

