# frozen_string_literal: true

require 'spec_helper'
require 'faraday'

RSpec.describe 'Chronicle::Resilience with Fibers & Circuit Breaker' do
  let(:cb) { Chronicle::Resilience::CircuitBreaker.new(threshold: 3, cooldown: 0.5) }

  before do
    Chronicle.reset_configuration!
    Chronicle.configure do |config|
      config.max_retries = 2
      config.retry_base_delay = 0.01
      config.retry_max_delay = 0.05
      config.circuit_breaker_threshold = 3
      config.circuit_breaker_cooldown = 0.5
    end
    Chronicle::Resilience.reset_circuit_breaker!
  end

  describe Chronicle::Resilience::CircuitBreaker do
    it 'starts in :closed state with 0 failures' do
      expect(cb.state).to eq(:closed)
      expect(cb.failure_count).to eq(0)
    end

    it 'transitions to :open when failure count reaches threshold' do
      3.times { cb.record_failure }
      expect(cb.state).to eq(:open)
      expect(cb.opened_at).not_to be_nil
    end

    it 'raises Chronicle::CircuitBreakerError when in :open state' do
      cb.force_open!
      expect { cb.check_state! }.to raise_error(Chronicle::CircuitBreakerError, /Circuit breaker is OPEN/)
    end

    it 'transitions to :half_open after cooldown duration expires' do
      cb.force_open!
      sleep 0.6 # Exceed 0.5s cooldown
      cb.check_state!
      expect(cb.state).to eq(:half_open)
    end

    it 'resets to :closed upon recording a success from :half_open' do
      cb.force_open!
      sleep 0.6
      cb.check_state! # Transitions to half_open
      cb.record_success
      expect(cb.state).to eq(:closed)
      expect(cb.failure_count).to eq(0)
    end

    it 're-opens immediately if a failure occurs in :half_open state' do
      cb.force_open!
      sleep 0.6
      cb.check_state! # half_open
      cb.record_failure
      expect(cb.state).to eq(:open)
    end
  end

  describe 'Fiber-aware Non-Blocking Sleep' do
    it 'uses Fiber.scheduler.kernel_sleep when a Fiber scheduler is active' do
      fake_scheduler = double('FiberScheduler')
      expect(fake_scheduler).to receive(:kernel_sleep).at_least(:once)

      allow(Fiber).to receive(:scheduler).and_return(fake_scheduler)

      attempts = 0
      expect do
        Chronicle::Resilience.with_retry(max_retries: 1, base_delay: 0.01, circuit_breaker: cb) do
          attempts += 1
          raise Chronicle::ConnectionError, 'Transient socket fail' if attempts == 1

          'success'
        end
      end.not_to raise_error
    end
  end

  describe 'Integration with CRubyClient Faraday HTTP requests' do
    let(:client) do
      Chronicle::Transport::CRubyClient.new(
        client_endpoint: 'http://localhost:8989',
        uri: 'datomic:dev://localhost:4334/test'
      )
    end
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }

    before do
      client.connection.adapter :test, stubs
    end

    after { stubs.verify_stubbed_calls }

    it 'trips circuit breaker on repeated Faraday connection failures and fails fast' do
      stubs.post('/api/transact') { [500, {}, { error: 'Transactor down' }.to_json] }

      custom_cb = Chronicle::Resilience::CircuitBreaker.new(threshold: 2, cooldown: 1.0)

      # Attempt 1 -> fails after retries -> records failures
      expect do
        Chronicle::Resilience.with_retry(max_retries: 1, base_delay: 0.001, circuit_breaker: custom_cb) do
          client.transact([[':db/add', 1, ':user/name', 'Test']])
        end
      end.to raise_error(Chronicle::TransactionError)

      # Breaker threshold = 2, failure count from attempt 1 (2 attempts) reached threshold
      expect(custom_cb.state).to eq(:open)

      # Subsequent call fails fast without HTTP request
      expect do
        Chronicle::Resilience.with_retry(circuit_breaker: custom_cb) do
          client.transact([[':db/add', 2, ':user/name', 'Fast Fail']])
        end
      end.to raise_error(Chronicle::CircuitBreakerError, /Circuit breaker is OPEN/)
    end
  end
end
