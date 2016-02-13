require 'simp/rake/pkg'
require 'spec_helper'


def skip_mock_tests_unless_enabled
  mock_var = 'SIMP_SPEC_mock'
  sudo_var = 'SIMP_SPEC_sudo'
  skip "`mock` tests disabled (use `#{mock_var}=yes` to enable)" unless  ENV[mock_var] == 'yes'
  skip "`sudo` tests disabled (use `#{sudo_var}=yes` to enable)" unless  ENV[sudo_var] == 'yes'
end

describe Simp::Rake::Pkg do
  before :all do
    dir        = File.expand_path( '../files', File.dirname( __FILE__ ) )
    @obj = Simp::Rake::Pkg.new( dir )
  end

  describe "#initialize" do
    it "initializes (smoke test)" do
      expect( @obj.class ).to eq Simp::Rake::Pkg
    end
  end

  describe '#mock_ensure_template_dir' do
    before :each do
      skip_mock_tests_unless_enabled
      chroot = 'epel-7-x86_64'
      @mock_template_dir = File.join(@obj.mock_root_dir, "#{chroot}-SIMP_BUILD_TEMPLATE")
      puts  `sudo rm -rf #{@mock_template_dir}`
      @obj.mock_ensure_template_dir( chroot )
    end

    it "creates the template directory" do
      skip_mock_tests_unless_enabled
      expect( File.directory? @mock_template_dir ).to be true
    end
  end
end
