require 'simp/ci/gitlab'
require 'spec_helper'

describe Simp::Ci::Gitlab do
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }

  describe '#acceptance_tests?' do
    it 'returns true when acceptance test with suite-specific nodesets exists' do
      proj_dir = File.join(files_dir, 'valid_job_suite_nodeset')
      expect( Simp::Ci::Gitlab.new(proj_dir).acceptance_tests? ).to be true
    end

=begin
    it 'returns true when acceptance test with implied global nodesets exists' do
    end

    it 'returns false when acceptance test dir does not exists' do
    end

    it 'returns false when only global nodesets exists' do
    end

    it 'returns false when only acceptance test suite skeleton exists' do
    end
=end

  end

  describe '#validate_acceptance_test_jobs' do
=begin
    it 'succeeds when no .gitlab-ci.yml file exists' do
      proj_dir = File.join(files_dir, 'no_gitlab_config')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to_not raise_error(Simp::Ci::Gitlab::JobError)
    end

    it 'succeeds when no acceptance tests are specified in the .gitlab-ci.yml file' do
      proj_dir = File.join(files_dir, 'no_acceptance_jobs')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to_not raise_error(Simp::Ci::Gitlab::JobError)
    end
=end

    it 'succeeds when acceptance test with suite-specific nodeset is correctly specified' do
      proj_dir = File.join(files_dir, 'valid_job_suite_nodeset')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to_not raise_error
    end

=begin
    it 'succeeds when acceptance test with nodeset link is correctly specified' do
      proj_dir = File.join(files_dir, 'valid_job_nodeset_link')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to_not raise_error(Simp::Ci::Gitlab::JobError)
    end

    it 'succeeds when acceptance test with nodeset dir link is correctly specified' do
      proj_dir = File.join(files_dir, 'valid_job_nodeset_dir_link')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to_not raise_error(Simp::Ci::Gitlab::JobError)
    end

    it 'succeeds when acceptance test with implied global nodeset is correctly specified' do
      proj_dir = File.join(files_dir, 'valid_job_global_nodeset')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
    end

    it 'fails when an acceptance job is missing suite and nodeset' do
      proj_dir = File.join(files_dir, 'job_missing_suite_and_nodeset')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to raise_error(Simp::Ci::Gitlab::JobError)
    end

    it 'fails when an acceptance job is missing nodeset' do
      proj_dir = File.join(files_dir, 'job_missing_nodeset')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to raise_error(Simp::Ci::Gitlab::JobError)
    end

    it 'fails when an acceptance job has invalid suite' do
      proj_dir = File.join(files_dir, 'job_invalid_suite')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to raise_error(Simp::Ci::Gitlab::JobError)
    end

    it 'fails when an acceptance job has invalid nodeset' do
      proj_dir = File.join(files_dir, 'job_invalid_nodeset')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to raise_error(Simp::Ci::Gitlab::JobError)
    end

    it 'fails when an acceptance job has nodeset with a broken link' do
      proj_dir = File.join(files_dir, 'job_broken_link_nodeset')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to raise_error(Simp::Ci::Gitlab::JobError)
    end

    it 'reports all job failures' do
      proj_dir = File.join(files_dir, 'multiple_invalid_jobs')
      expect{ Simp::Ci::Gitlab.new(proj_dir).validate_acceptance_test_jobs }.
        to raise_error(Simp::Ci::Gitlab::JobError)
    end
=end
  end

end
