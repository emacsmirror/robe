# frozen_string_literal: true

require 'robe/sash/doc_for'
require 'uri'
require 'active_support/core_ext/kernel' # https://github.com/pry/pry-doc/issues/16

describe Robe::Sash::DocFor do
  klass = described_class

  it 'returns hash for a basic class' do
    c = Class.new do
      # Some words.
      def quux(a, *b, &c); end
    end

    k = klass.new(c.instance_method(:quux))
    expect(k.format).to eq({docstring: "Some words.\n",
                            source: "def quux(a, *b, &c); end\n",
                            aliases: [],
                            visibility: :public})
  end

  it 'shows docs for stdlib classes' do
    hash = klass.new(URI.method(:parse)).format
    expect(hash[:docstring]).to match(/URI.*from.*string/)
  end

  it 'returns private visibility for Kernel#puts' do
    expect(klass.new(Kernel.instance_method(:puts)).format[:visibility])
      .to eq(:private)
  end

  it 'returns public visibility for Kernel.puts' do
    # And doesn't do "Scanning and caching *.c files".
    expect(klass.new(Kernel.method(:puts)).format[:visibility]).to eq(:public)
  end

  it 'returns protected visibility' do
    method = Class.new.class_exec do
      protected

      def foo; end
      instance_method(:foo)
    end
    expect(klass.new(method).format[:visibility]).to be(:protected)
  end

  it 'mentions pry-doc when relevant' do
    hide_const('PryDoc')
    struct = described_class.method_struct(String.instance_method(:gsub))

    if RUBY_ENGINE == 'ruby'
      expect(struct.source).to be_nil
      expect(struct.docstring).to match(/pry-doc/)
    else
      expect(struct.docstring).to eq('')
      expect(struct.source).to start_with('def gsub(')
    end
  end

  context 'native methods', RUBY_VERSION >= '2.6' && :skip do
    let(:c) { described_class }

    context 'String#gsub info fields' do
      let(:struct) { c.method_struct(String.instance_method(:gsub)) }

      if RUBY_ENGINE == 'ruby'
        it { expect(struct.docstring).to start_with('Returns') }
        it { expect(struct.source).to start_with('static VALUE') }
      else
        it { expect(struct.docstring).to eq('') }
        it { expect(struct.source).to start_with('def gsub(') }
      end
    end

    context 'Array#map has an alias' do
      let(:struct) { c.method_struct(Array.instance_method(:map)) }
      it { expect(struct.aliases).to eq([:collect]) }
    end

    context 'Set#include? has an alias' do
      let(:struct) { c.method_struct(Set.instance_method(:include?)) }
      it { expect(struct.aliases).to include(:member?) }
    end

    context 'Know the appropriate amount about Kernel#send' do
      let(:struct) { c.method_struct(Kernel.instance_method(:send)) }

      it { expect(struct.visibility).to eq(:public) }
      it { expect(struct.aliases).to eq([]) }

      if RUBY_ENGINE == 'ruby'
        it { expect(struct.docstring).to include('Invokes the method') }
        it { expect(struct.source).to start_with("VALUE\nrb_f_send") }
      else
        it { expect(struct.docstring).to include('class or superclass') }
        it { expect(struct.source).to start_with('def kind_of?(') }
      end
    end
  end

  context 'pure methods' do
    let(:c) { described_class }

    context 'method quux defined' do
      # First line,
      # second line.
      def quux(n); end

      it 'has the docstring' do
        expect(c.method_struct(method(:quux)).docstring).to eq("First line,\n" \
                                                               "second line.\n")
      end

      it 'has the source' do
        expect(c.method_struct(method(:quux)).source).to eq("def quux(n); end\n")
      end

      it 'has no aliases' do
        expect(c.method_struct(method(:quux)).aliases).to eq([])
      end
    end

    it 'should return the source for one-line methods' do
      def xuuq(); end
      expect(c.method_struct(method(:xuuq)).source).to eq("def xuuq(); end\n")
    end

    it 'should return empty docstring when none' do
      def xuuq(m); end

      struct = c.method_struct(method(:xuuq))
      expect(struct.docstring).to eq('')
      expect(struct.source).not_to be_empty
    end
  end

  context 'dynamically defined' do
    let(:kls) { eval 'Class.new do;def foo;42;end;end' }
    let(:c) { described_class }

    it 'returns no docstring' do
      expect(c.method_struct(kls.instance_method(:foo)).docstring).to be_empty
    end

    it 'returns comment about dynamic definition as the source' do
      expect(c.method_struct(kls.instance_method(:foo)).source)
        .to include('outside of a source file')
    end
  end
end
