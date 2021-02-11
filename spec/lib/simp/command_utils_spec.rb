require 'simp/command_utils'
require 'spec_helper'

describe Simp::CommandUtils do
  RSpec.configure do |c|
    c.include Simp::CommandUtils
  end

  describe '.which' do
    it 'should return location of command that exists' do
      expect(Facter::Core::Execution).to receive(:which).with('ls').and_return('/usr/bin/ls')
      expect( which('ls') ).to eq('/usr/bin/ls')
    end

    it 'should return nil if command does not exist by default' do
      expect( which('/does/not/exist/command') ).to be nil
    end

    it 'should fail if command does not exist if fail=true' do
      expect{ which('/does/not/exist/command', true) }.to raise_error(
        RuntimeError, /Warning: Command \/does\/not\/exist\/command not found/)
    end

    it 'should cache commands' do
      allow(Facter::Core::Execution).to receive(:which).with('ls').and_return('/path1/ls', '/path2/ls')
      expect( which('ls') ).to eq('/path1/ls')
    end
  end
end
