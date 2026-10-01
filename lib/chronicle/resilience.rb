# frozen_string_literal: true

require 'mutex_m'

module Chronicle
  module Resilience
    class CircuitBreaker
      attr_reader :state, :failure_count, :opened_at

      def initialize(threshold: nil, cooldown: nil)
        @mutex = Mutex.new
        @state = :closed
        @failure_count = 0
        @opened_at = nil
        @threshold = threshold
        @cooldown = cooldown
      end

      def threshold
        @threshold || (Chronicle.configuration ? Chronicle.configuration.circuit_breaker_threshold : 5)
      end

      def cooldown
        @cooldown || (Chronicle.configuration ? Chronicle.configuration.circuit_breaker_cooldown : 10.0)
      end

      def check_state!
        @mutex.synchronize do
          case @state
          when :open
            if Time.now - @opened_at >= cooldown
              @state = :half_open
            else
              raise Chronicle::CircuitBreakerError,
                    "Circuit breaker is OPEN. Datomic Transactor requests failing fast (opened at #{@opened_at})."
            end
          when :half_open, :closed
            # Allow execution
          end
        end
      end

      def record_success
        @mutex.synchronize do
          @failure_count = 0
          @state = :closed
          @opened_at = nil
        end
      end

      def record_failure
        @mutex.synchronize do
          @failure_count += 1
          if @failure_count >= threshold || @state == :half_open
            @state = :open
            @opened_at = Time.now
          end
        end
      end

      def reset!
        @mutex.synchronize do
          @state = :closed
          @failure_count = 0
          @opened_at = nil
        end
      end

      def force_open!
        @mutex.synchronize do
          @state = :open
          @opened_at = Time.now
        end
      end
    end

    class << self
      def global_circuit_breaker
        @global_circuit_breaker ||= CircuitBreaker.new
      end

      def reset_circuit_breaker!
        global_circuit_breaker.reset!
      end

      def retryable_exceptions
        @retryable_exceptions ||= [
          Chronicle::ConnectionError,
          Chronicle::TransactionError,
          Faraday::TimeoutError,
          Faraday::ConnectionFailed,
          Errno::ECONNREFUSED,
          Errno::ETIMEDOUT
        ]
      end

      def with_retry(max_retries: nil, base_delay: nil, max_delay: nil, circuit_breaker: nil)
        nested_retry = Thread.current[:chronicle_retry_depth].to_i.positive?
        cb = circuit_breaker || (nested_retry ? CircuitBreaker.new : global_circuit_breaker)
        config = Chronicle.configuration

        retries = max_retries || (config ? config.max_retries : 5)
        delay   = base_delay   || (config ? config.retry_base_delay : 0.1)
        max_d   = max_delay    || (config ? config.retry_max_delay : 2.0)

        begin
          Thread.current[:chronicle_retry_depth] = Thread.current[:chronicle_retry_depth].to_i + 1
          cb.check_state!

          attempt = 0
          begin
            attempt += 1
            result = yield
            cb.record_success
            result
          rescue StandardError => e
            if retryable?(e)
              cb.record_failure
              if attempt <= retries
                sleep_time = [delay * (2**(attempt - 1)), max_d].min
                jitter = rand(0.0..0.1) * sleep_time
                sleep_backoff(sleep_time + jitter)
                retry
              end
            end
            raise e
          end
        ensure
          Thread.current[:chronicle_retry_depth] -= 1
        end
      end

      def sleep_backoff(duration)
        if defined?(Fiber) && Fiber.respond_to?(:scheduler) && Fiber.scheduler
          Fiber.scheduler.kernel_sleep(duration)
        else
          sleep(duration)
        end
      end

      private

      def retryable?(exception)
        retryable_exceptions.any? { |klass| exception.is_a?(klass) } ||
          exception.message.to_s.match?(/transactor-unavailable|queue-full|backpressure|timeout/i)
      end
    end
  end
end
