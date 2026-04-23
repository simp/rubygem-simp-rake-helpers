# frozen_string_literal: true

require 'simp/command_utils'
require 'spec_helper'

describe Simp::CommandUtils do
  RSpec.configure do |c|
    c.include described_class
  end

  describe '.which' do
    it 'returns location of command that exists' do
      expect(Facter::Core::Execution).to receive(:which).with('ls').and_return('/usr/bin/ls')
      expect(which('ls')).to eq('/usr/bin/ls')
    end

    it 'returns nil if command does not exist by default' do
      expect(which('/does/not/exist/command')).to be_nil
    end

    it 'fails if command does not exist if fail=true' do
      expect { which('/does/not/exist/command', true) }.to raise_error(
        RuntimeError, %r{Warning: Command /does/not/exist/command not found}
      )
    end

    it 'caches commands' do
      allow(Facter::Core::Execution).to receive(:which).with('ls').and_return('/path1/ls', '/path2/ls')
      expect(which('ls')).to eq('/path1/ls')
    end
  end
end
