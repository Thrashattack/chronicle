# frozen_string_literal: true

module Chronicle
  class TransactionCoordinator
    attr_reader :basis_t, :tx_id, :transport, :transacted_datoms, :created_entity_ids, :datomic_result

    class << self
      def transact(transport: nil, &block)
        new(transport: transport).transact(&block)
      end
    end

    def initialize(transport: nil)
      @transport = transport || Chronicle::Transport.client
      @transacted_datoms = []
      @created_entity_ids = []
      @basis_t = nil
      @tx_id = nil
      @datomic_result = nil
    end

    def transact
      yield(self)
      self
    rescue StandardError => e
      rollback!(e)
    end

    def datomic(datoms_or_model)
      datoms = convert_to_datoms(datoms_or_model)
      @transacted_datoms.concat(datoms)

      @datomic_result = @transport.transact(datoms) || {}

      @basis_t = @datomic_result[:basis_t] || @datomic_result["basis_t"] || Time.now.to_i
      @tx_id = @datomic_result[:tx_id] || @datomic_result["tx_id"] || @basis_t

      if @datomic_result[:tempids]
        @created_entity_ids.concat(@datomic_result[:tempids].values)
      end

      datoms.each do |d|
        if d.is_a?(Array) && d[1].is_a?(Numeric)
          @created_entity_ids << d[1]
        end
      end
      @created_entity_ids.uniq!

      @datomic_result
    end

    def postgres
      raise Chronicle::TransactionError, "No Datomic transaction has been executed yet" unless @basis_t

      if defined?(ActiveRecord::Base)
        ActiveRecord::Base.transaction do
          yield(self)
        end
      else
        yield(self)
      end
    end

    def read_your_own_write(model_class, finder_attributes = {})
      raise Chronicle::TransactionError, "No basis-t available for read-your-own-write" unless @basis_t

      model_class.as_of(@basis_t).where(finder_attributes)
    end

    private

    def convert_to_datoms(datoms_or_model)
      if datoms_or_model.respond_to?(:to_datoms)
        datoms_or_model.to_datoms
      elsif datoms_or_model.is_a?(Array)
        datoms_or_model
      else
        raise ArgumentError, "Expected datoms array or an object responding to #to_datoms"
      end
    end

    def rollback!(cause)
      if @datomic_result && (@created_entity_ids.any? || @transacted_datoms.any?)
        execute_compensating_retraction
      end

      raise Chronicle::TransactionError, "Cross-database transaction rolled back due to: #{cause.message}"
    end

    def execute_compensating_retraction
      retraction_datoms = []

      @created_entity_ids.each do |eid|
        retraction_datoms << [":db/retractEntity", eid]
      end

      if retraction_datoms.empty?
        @transacted_datoms.each do |datom|
          if datom.is_a?(Array) && datom[0] == ":db/add"
            retraction_datoms << [":db/retract", datom[1], datom[2], datom[3]]
          end
        end
      end

      @transport.transact(retraction_datoms) if retraction_datoms.any?
    rescue StandardError => e
      warn("[Chronicle] Compensating rollback failed: #{e.message}")
    end
  end
end
