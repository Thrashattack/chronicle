# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chronicle::Relation do
  describe '#as_of' do
    it 'attaches as_of timestamp to time_travel_options' do
      timestamp = Time.now
      rel = HistoricalRecord.all.extending(Chronicle::Model::TimeTravelExtension).as_of(timestamp)
      expect(rel.time_travel_options[:as_of]).to eq(timestamp)
    end
  end

  describe '#since' do
    it 'attaches since timestamp to time_travel_options' do
      timestamp = 1.day.ago
      rel = HistoricalRecord.all.extending(Chronicle::Model::TimeTravelExtension).since(timestamp)
      expect(rel.time_travel_options[:since]).to eq(timestamp)
    end
  end
end
