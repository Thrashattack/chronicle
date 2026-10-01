# frozen_string_literal: true

require 'spec_helper'
require 'faraday'

RSpec.describe 'Transport Layer Interop Specs (CRuby HTTP vs JRuby JVM)' do
  let(:uri) { 'datomic:dev://localhost:4334/chronicle_test' }
  let(:client_endpoint) { 'http://localhost:8989' }

  describe 'CRuby Transport (CRubyClient - HTTP Protocol)' do
    subject(:transport) do
      Chronicle::Transport::CRubyClient.new(
        client_endpoint:,
        uri:
      )
    end

    let(:stubs) { Faraday::Adapter::Test::Stubs.new }

    before do
      # Configure Faraday test adapter for HTTP mocking
      transport.connection.builder.handlers.pop if transport.connection.builder.handlers.last == Faraday::Adapter::NetHttp
      transport.connection.adapter :test, stubs
    end

    after do
      stubs.verify_stubbed_calls
    end

    it 'sends HTTP POST /api/connect with URI payload' do
      stubs.post('/api/connect') do |env|
        expect(env.url.to_s).to eq('http://localhost:8989/api/connect')
        body = JSON.parse(env.body)
        expect(body['uri']).to eq(uri)
        [200, { 'Content-Type' => 'application/json' }, { status: 'connected' }.to_json]
      end

      expect(transport.connect!).to be(true)
    end

    it 'sends HTTP POST /api/transact and updates basis_t' do
      datoms = [[':db/add', ':temp_1', ':user/name', 'Alice']]

      stubs.post('/api/transact') do |env|
        body = JSON.parse(env.body)
        expect(body['uri']).to eq(uri)
        expect(body['tx_data']).to eq(datoms)
        [
          200,
          { 'Content-Type' => 'application/json' },
          { 'basis_t' => 10_042, 'tx_data' => datoms, 'db_after' => 'db_ref_10042' }.to_json
        ]
      end

      result = transport.transact(datoms)
      expect(result[:basis_t]).to eq(10_042)
      expect(transport.basis_t).to eq(10_042)
    end

    it 'sends HTTP POST /api/query and returns results array' do
      query = [:find, '?e', :in, '$', '?param_1', :where, ['?e', ':user/name', '?param_1']]

      stubs.post('/api/query') do |env|
        body = JSON.parse(env.body)
        expect(body['query']).to eq(query.map(&:to_s))
        expect(body['args']).to eq(['Alice'])
        [
          200,
          { 'Content-Type' => 'application/json' },
          { 'results' => [[101, 'Alice']] }.to_json
        ]
      end

      results = transport.q(query.map(&:to_s), 'Alice')
      expect(results).to eq([[101, 'Alice']])
    end

    it 'raises Chronicle::ConnectionError on HTTP 500 failure' do
      stubs.post('/api/connect') do
        [500, { 'Content-Type' => 'application/json' }, { error: 'Transactor down' }.to_json]
      end

      expect { transport.connect! }.to raise_error(Chronicle::ConnectionError, /Failed to connect/)
    end
  end

  describe 'CRuby REST Transport' do
    it 'sends the Datalog form under the REST :query key' do
      transport = Chronicle::Transport::CRubyClient.new(
        client_endpoint: 'http://localhost:8001',
        uri: 'datomic:dev://localhost:4334/chronicle_test',
        rest: true
      )
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post('/api/query') do |env|
          expect(env.body).to eq('{:query [:find ?e] :args [{:db/alias "dev/chronicle_test" :as-of nil :since nil}]}')
          [200, { 'Content-Type' => 'application/edn' }, '[]']
        end
      end
      transport.connection.adapter :test, stubs

      expect(transport.q([:find, '?e'], 'db/alias' => 'dev/chronicle_test', 'as-of' => nil, 'since' => nil)).to eq([])
      stubs.verify_stubbed_calls
    end
  end

  describe 'JRuby Transport (JRubyPeer - JVM Interop Protocol)' do
    subject(:transport) do
      Chronicle::Transport::JRubyPeer.new(uri:)
    end

    before do
      ENV['SPEC_ALLOW_JRUBY_MOCK'] = 'true'
    end

    after do
      ENV.delete('SPEC_ALLOW_JRUBY_MOCK')
    end

    context 'when running in JRuby environment with Java interop mocks' do
      let(:mock_peer_class) { class_double('Java::Datomic::Peer') }
      let(:mock_connection) { instance_double('Java::Datomic::Connection') }
      let(:mock_future) { instance_double('Java::Datomic::ListenableFuture') }
      let(:mock_tx_map) { instance_double('Java::Util::Map') }

      before do
        stub_const('Java::Datomic::Peer', mock_peer_class)
        stub_const('Java::Datomic::Peer::BASIS_T', ':db/basis-t')
        stub_const('Java::Datomic::Peer::DB_BEFORE', ':db/before')
        stub_const('Java::Datomic::Peer::DB_AFTER', ':db/after')
      end

      it 'invokes Java::Datomic::Peer.connect on connect!' do
        expect(mock_peer_class).to receive(:connect).with(uri).and_return(mock_connection)

        transport.connect!
        expect(transport.peer_connection).to eq(mock_connection)
      end

      it 'invokes Java Peer transact and extracts basis_t from Java Map' do
        datoms = [[':db/add', ':temp_1', ':user/name', 'Bob']]
        transport.instance_variable_set(:@peer_connection, mock_connection)

        expect(mock_connection).to receive(:transact).with(datoms).and_return(mock_future)
        expect(mock_future).to receive(:get).and_return(mock_tx_map)
        expect(mock_tx_map).to receive(:get).with(':db/basis-t').and_return(10_099)
        expect(mock_tx_map).to receive(:get).with(':db/before').and_return('db_before_ref')
        expect(mock_tx_map).to receive(:get).with(':db/after').and_return('db_after_ref')

        result = transport.transact(datoms)
        expect(result[:basis_t]).to eq(10_099)
        expect(result[:db_before]).to eq('db_before_ref')
      end

      it 'invokes Java::Datomic::Peer.q for sub-millisecond in-process query resolution' do
        query = [:find, '?e', :in, '$', '?name', :where, ['?e', ':user/name', '?name']]
        transport.instance_variable_set(:@peer_connection, mock_connection)
        mock_db = instance_double('Java::Datomic::Db')

        expect(mock_peer_class).to receive(:q).with(query, mock_db, 'Bob').and_return([[202, 'Bob']])

        results = transport.q(query, mock_db, 'Bob')
        expect(results).to eq([[202, 'Bob']])
      end

      it 'converts namespaced Ruby symbols into single-colon Clojure keywords' do
        api = Chronicle::Transport::JRubyClient::ClojureApi.allocate
        allow(api).to receive(:keyword).with('wallet/name').and_return(:wallet_name)

        expect(api.send(:clojure_value, :':wallet/name')).to eq(:wallet_name)
      end
    end

    context 'when attempted under CRuby without JRuby runtime flags' do
      before do
        ENV.delete('SPEC_ALLOW_JRUBY_MOCK')
        allow(Chronicle::Transport).to receive(:jruby?).and_return(false)
      end

      it 'raises Chronicle::Error enforcing JRuby runtime guard' do
        expect { transport.connect! }.to raise_error(Chronicle::Error, /can only be run under JRuby/)
      end
    end
  end
end
