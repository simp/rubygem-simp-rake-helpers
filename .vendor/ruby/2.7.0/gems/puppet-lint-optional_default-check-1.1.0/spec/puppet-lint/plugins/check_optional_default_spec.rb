# frozen_string_literal: true

require 'spec_helper'

describe 'optional_default' do
  let(:msg) { 'Optional parameter defaults to something other than undef' }

  %w[define class].each do |type|
    context "#{type} with Optional parameter defaulting to string on single line" do
      let(:code) { "#{type} test(Optional $foo = 'test') { }" }

      it 'detects a single problem' do
        expect(problems).to have(1).problem
      end

      col = (type == 'class' ? 21 : 22)
      it 'creates a warning' do
        expect(problems).to contain_warning(msg).on_line(1).in_column(col)
      end

      context 'with trailing comma' do
        let(:code) { "#{type} test(Optional $foo = 'test',) { }" }

        it 'detects a single problem' do
          expect(problems).to have(1).problem
        end

        col = (type == 'class' ? 21 : 22)
        it 'creates a warning' do
          expect(problems).to contain_warning(msg).on_line(1).in_column(col)
        end
      end
    end

    context "#{type} with Optional parameter defaulting to string on multiple lines" do
      let(:code) do
        <<~CODE
          #{type} test(
            Optional $foo = 'test'
          ){
          }
        CODE
      end

      it 'detects a single problem' do
        expect(problems).to have(1).problem
      end

      it 'creates a warning' do
        expect(problems).to contain_warning(msg).on_line(2).in_column(12)
      end
    end

    context "#{type} with Optional parameter defaulting to undef on single line" do
      let(:code) { "#{type} test(Optional $foo = undef) { }" }

      it 'detects no problems' do
        expect(problems).to have(0).problem
      end

      context 'with trailing comma' do
        let(:code) { "#{type} test(Optional $foo = undef) { }" }

        it 'detects no problems' do
          expect(problems).to have(0).problem
        end
      end
    end

    context "#{type} with Optional[String[1]] parameter defaulting to string on single line" do
      let(:code) { "#{type} test(Optional[String[1]] $foo = 'test') { }" }

      it 'detects a single problem' do
        expect(problems).to have(1).problem
      end

      col = (type == 'class' ? 32 : 33)
      it 'creates a warning' do
        expect(problems).to contain_warning(msg).on_line(1).in_column(col)
      end
    end

    context "#{type} with a mandatory parameter followed by an Optional[Hash] parameter with a non undef default" do
      let(:code) do
        <<~CODE
          #{type} test(
            String         $foo,
            Optional[Hash] $bar = {
              'a' => 'b',
              'c' => 'd'
            },
          ){
          }
        CODE
      end

      it 'detects a single problem' do
        expect(problems).to have(1).problem
      end

      it 'creates a warning' do
        expect(problems).to contain_warning(msg).on_line(3).in_column(18)
      end
    end

    context "#{type} with a mandatory parameter followed by an Optional[Hash] parameter that default to the result of a function" do
      let(:code) do
        <<~CODE
          #{type} test(
            String         $foo,
            Optional[Hash] $bar = some::func('foo'),
          ){
          }
        CODE
      end

      it 'detects no problems' do
        expect(problems).to have(0).problem
      end
    end

    context "#{type} with a mandatory parameter followed by an Optional[Hash] parameter that default to the result of a function called with dot notation" do
      let(:code) do
        <<~CODE
          #{type} test(
            String         $foo,
            Optional[Hash] $bar = 'foo'.func,
          ){
          }
        CODE
      end

      it 'detects no problems' do
        expect(problems).to have(0).problem
      end
    end

    context "Complex #{type} with multiple issues and comments" do
      let(:code) do
        <<~CODE
          #{type} test (
            $a, # No type or default
            String                  $b   = 'somestring',
            Optional[String[1]]     $c   = 'foobar', # This should generate a warning
            Optional[Enum[
              'a',
              'b',
              ]
            ]                       $fuz = 'a', # As should this
            Optional                $d   = $foo::param::c,
            Optional[Array[String]] $e   = [] # Another warning here (also note no trailing comma!)
          ){
            notice('test')
          }
        CODE
      end

      it 'detects 3 problems' do
        expect(problems).to have(3).problem
      end

      it { expect(problems).to contain_warning(msg).on_line(4).in_column(27) }
      it { expect(problems).to contain_warning(msg).on_line(9).in_column(27) }
      it { expect(problems).to contain_warning(msg).on_line(11).in_column(27) }
    end

    context "#{type} with Optional parameter with array operation" do
      let(:code) do
        <<~CODE
          #{type} test(
            Optional[Array] $hostnames = ['foo.example.com', 'bar.example.com'] - $facts['fqdn'],
          ){
          }
        CODE
      end

      it 'detects a single problem' do
        expect(problems).to have(1).problem
      end

      it { expect(problems).to contain_warning(msg).on_line(2).in_column(19) }
    end
  end
  context 'with class with Optional parameter with no apparent default' do
    let(:code) { 'class test(Optional $foo) { }' }

    # There's a good chance the parameter default is actually in hiera as `~`.
    it 'detects no problems' do
      expect(problems).to have(0).problem
    end
  end

  context 'with defined type with Optional parameter with no default' do
    let(:code) { 'define test(Optional $foo) { }' }

    it 'detects a single problem' do
      expect(problems).to have(1).problem
    end
  end
end
