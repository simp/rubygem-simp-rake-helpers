require 'spec_helper'

module Beaker
  module Options
    describe '#parse_subcommand_options' do
      let(:home_options_file_path) {ENV['HOME']+'/.beaker/subcommand_options.yaml'}
      let(:parser_mod) { Beaker::Options::SubcommandOptionsParser }
      let( :parser ) {parser_mod.parse_subcommand_options(argv, options_file)}
      let( :file_parser ){parser_mod.parse_options_file({})}
      let( :argv ) {[]}
      let( :options_file ) {""}

      it 'returns an empty OptionsHash if not executing a subcommand' do
        expect(parser).to be_kind_of(OptionsHash)
        expect(parser).to be_empty
      end

      describe 'when the subcommand is init' do
        let( :argv ) {['init']}

        it 'returns an empty OptionsHash' do
          expect(parser).to be_kind_of(OptionsHash)
          expect(parser).to be_empty
        end
      end

      describe 'when the subcommand is not init' do
        let( :argv ) {['provision']}
        let( :options_file ) {home_options_file_path}

        it 'calls parse_options_file with subcommand options file when home_dir is false' do
          allow(parser_mod).to receive(:execute_subcommand?).with('provision').and_return true
          allow(parser_mod).to receive(:parse_options_file).with(Beaker::Subcommands::SubcommandUtil::SUBCOMMAND_OPTIONS)
        end

        it 'calls parse_options_file with home directory options file when home_dir is true' do
          allow(parser_mod).to receive(:execute_subcommand?).with('provision').and_return true
          allow(parser_mod).to receive(:parse_options_file).with(home_options_file_path)
        end

        it 'checks for file existence and loads the YAML file' do
          allow(File).to receive(:exist?).and_return true
          allow(YAML).to receive(:load_file).and_return({})
          expect(file_parser).to be_kind_of(Hash)
          expect(file_parser).not_to be_kind_of(OptionsHash)
        end


        it 'returns an empty options hash when file does not exist' do
          allow(File).to receive(:exist?).and_return false
          expect(parser).to be_kind_of(OptionsHash)
          expect(parser).to be_empty
        end
      end
    end
  end
end
