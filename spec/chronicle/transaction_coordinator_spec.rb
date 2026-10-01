# frozen_string_literal: true

require "spec_helper"

RSpec.describe Chronicle::TransactionCoordinator do
  let(:mock_transport) { instance_double("Chronicle::Transport::CRubyClient") }

  # Test dummy models
  let(:historical_record_class) do
    Class.new do
      include Chronicle::Model

      def self.name
        "HistoricalRecord"
      end

      def self.table_name
        "historical_records"
      end

      datomic_attribute :title, :string
      datomic_attribute :payload, :string

      attr_accessor :title, :payload, :id

      def initialize(attrs = {})
        @title = attrs[:title]
        @payload = attrs[:payload]
        @id = attrs[:id]
      end

      def read_attribute(name)
        public_send(name)
      end
    end
  end

  let(:postgres_audit_class) do
    Class.new do
      attr_accessor :datomic_tx_id, :status

      def self.create!(attrs)
        new.tap do |record|
          record.datomic_tx_id = attrs[:datomic_tx_id]
          record.status = attrs[:status]
        end
      end
    end
  end

  describe "#transact" do
    context "when both Datomic and PostgreSQL operations succeed" do
      it "coordinates writes and attaches basis_t to the transaction" do
        datoms = [
          [":db/add", ":temp_id", ":historical_record/title", "Audit Event 100"],
          [":db/add", ":temp_id", ":historical_record/payload", "High-volume data"]
        ]

        expect(mock_transport).to receive(:transact).with(datoms).and_return(
          basis_t: 20045,
          tx_id: 17120045,
          tempids: { ":temp_id" => 1001 }
        )

        postgres_record = nil

        result = described_class.transact(transport: mock_transport) do |tx|
          tx.datomic(datoms)

          tx.postgres do
            postgres_record = postgres_audit_class.create!(
              datomic_tx_id: tx.basis_t,
              status: "synced"
            )
          end
        end

        expect(result.basis_t).to eq(20045)
        expect(postgres_record.datomic_tx_id).to eq(20045)
        expect(postgres_record.status).to eq("synced")
      end
    end

    context "when PostgreSQL operation fails after Datomic write succeeds" do
      it "executes a compensating retraction in Datomic and raises TransactionError" do
        datoms = [
          [":db/add", ":temp_id", ":historical_record/title", "Failed Event"]
        ]

        # 1. Primary assertion
        expect(mock_transport).to receive(:transact).with(datoms).and_return(
          basis_t: 20046,
          tx_id: 17120046,
          tempids: { ":temp_id" => 1002 }
        )

        # 2. Compensating rollback retraction expectation
        expect(mock_transport).to receive(:transact).with([
          [":db/retractEntity", 1002]
        ]).and_return(basis_t: 20047)

        expect do
          described_class.transact(transport: mock_transport) do |tx|
            tx.datomic(datoms)

            tx.postgres do
              raise "PostgreSQL foreign key violation or Aurora DB connection failure"
            end
          end
        end.to raise_error(
          Chronicle::TransactionError,
          /Cross-database transaction rolled back due to: PostgreSQL foreign key violation/
        )
      end
    end

    context "when Datomic write fails directly" do
      it "prevents PostgreSQL execution entirely and raises exception" do
        expect(mock_transport).to receive(:transact).and_raise(Chronicle::ConnectionError.new("Datomic Transactor unavailable"))
        postgres_executed = false

        expect do
          described_class.transact(transport: mock_transport) do |tx|
            tx.datomic([[':db/add', ':temp', ':a/b', 'val']])
            tx.postgres { postgres_executed = true }
          end
        end.to raise_error(Chronicle::TransactionError)

        expect(postgres_executed).to be false
      end
    end
  end

  describe "#read_your_own_write" do
    it "constructs an Active Record relation scoped with the exact basis_t snapshot" do
      allow(mock_transport).to receive(:transact).and_return(basis_t: 30010)

      coordinator = described_class.new(transport: mock_transport)
      coordinator.transact do |tx|
        tx.datomic([[':db/add', ':temp_id', ':historical_record/title', 'Instant Read']])
      end

      relation = coordinator.read_your_own_write(historical_record_class, title: 'Instant Read')
      expect(relation.time_travel_options[:as_of]).to eq(30010)
    end
  end
end
