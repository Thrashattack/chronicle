# frozen_string_literal: true

require "spec_helper"

RSpec.describe Chronicle::Resilience do
  describe ".with_retry" do
    it "executes block without delay on immediate success" do
      calls = 0
      result = described_class.with_retry(max_retries: 3, base_delay: 0.01) do
        calls += 1
        "success"
      end

      expect(result).to eq("success")
      expect(calls).to eq(1)
    end

    it "retries on transient ConnectionError and succeeds on subsequent attempt" do
      calls = 0
      result = described_class.with_retry(max_retries: 3, base_delay: 0.001) do
        calls += 1
        raise Chronicle::ConnectionError, "Transactor queue-full" if calls < 2

        "recovered"
      end

      expect(result).to eq("recovered")
      expect(calls).to eq(2)
    end

    it "re-raises exception after exhausting max retries" do
      calls = 0
      expect do
        described_class.with_retry(max_retries: 2, base_delay: 0.001) do
          calls += 1
          raise Chronicle::TransactionError, "Transactor unavailable"
        end
      end.to raise_error(Chronicle::TransactionError)

      expect(calls).to eq(3) # Initial + 2 retries
    end
  end
end
