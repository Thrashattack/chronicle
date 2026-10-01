# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chronicle::Transport do
  describe '.build' do
    context "when running under CRuby (RUBY_ENGINE != 'jruby')" do
      before do
        allow(described_class).to receive(:jruby?).and_return(false)
      end

      it 'instantiates a CRubyClient transport' do
        transport = described_class.build(client_endpoint: 'http://localhost:8989',
                                          uri: 'datomic:dev://localhost:4334/app')
        expect(transport).to be_a(Chronicle::Transport::CRubyClient)
      end
    end

    context "when running under JRuby (RUBY_ENGINE == 'jruby')" do
      before do
        allow(described_class).to receive(:jruby?).and_return(true)
      end

      it 'instantiates a JRubyPeer transport' do
        transport = described_class.build(uri: 'datomic:free://localhost:4334/app')
        expect(transport).to be_a(Chronicle::Transport::JRubyPeer)
      end
    end
  end

  describe 'Initializer & Configuration' do
    it 'configures endpoint, uri, and pool_size via Chronicle.configure' do
      Chronicle.configure do |config|
        config.uri = 'datomic:mem://test_db'
        config.client_endpoint = 'http://127.0.0.1:8989'
        config.pool_size = 10
      end

      expect(Chronicle.configuration.uri).to eq('datomic:mem://test_db')
      expect(Chronicle.configuration.client_endpoint).to eq('http://127.0.0.1:8989')
      expect(Chronicle.configuration.pool_size).to eq(10)
    end
  end
end
