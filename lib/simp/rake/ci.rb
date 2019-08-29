require 'rake/tasklib'
require 'simp/ci/gitlab'

module Simp; end
module Simp::Rake
  class Ci < ::Rake::TaskLib
    def initialize( dir )
       @base_dir = dir
       define
    end

    def define
      namespace :simp do

        desc 'Validate CI configuration'
        task :ci_lint => [:gitlab_ci_lint] do
        end

        desc 'Validate GitLab CI configuration'
        task :gitlab_ci_lint do
          Simp::Ci::Gitlab::validate_acceptance_tests(@base_dir)
        end

      end
    end
  end
end
