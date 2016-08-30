require 'simp'
require 'spec_helper'

describe Simp::Logger do
  RSpec.configure do |c|
    c.include Simp::Logger
  end
  before { @log = Logging.logger[self] }

  describe Logging.logger.root.appenders[0] do
    it 'is a stderr appender' do
      expect(subject).to be_an_instance_of(Logging::Appenders::Stderr)
    end

    it 'logs messages of level "error" and higher' do
      expect(subject.level).to eq(2)
    end
  end

  describe Logging.logger.root.appenders[1] do
    it 'is a file appender' do
      expect(subject).to be_an_instance_of(Logging::Appenders::File)
    end

    it 'writes to "log/output.log"' do
      expect(subject.name).to eq('log/output.log')
    end

    it 'logs all messages' do
      expect(subject.level).to eq(0)
    end
  end

  describe '#log_run' do
    context 'when passed a command string' do
      subject { log_run('echo foo; echo bar 1>&2') }

      it { is_expected.to be_an_instance_of(Process::Waiter) }

      it 'logs stderr output to the console' do
        skip
      end

      it 'writes all output to the log file' do
        skip
      end
    end
  end
end
