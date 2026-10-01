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

  describe 'Active Record ordering' do
    it 'orders hydrated records for ordinary model relations' do
      transport = instance_double(Chronicle::Transport::CRubyClient)
      allow(transport).to receive(:db).and_return(:database)
      allow(transport).to receive(:q).and_return([[2], [1]])
      allow(User).to receive(:chronicle_transport).and_return(transport)

      records = [
        User.instantiate('id' => '2', 'name' => 'Zed'),
        User.instantiate('id' => '1', 'name' => 'Ada')
      ]
      allow(Chronicle::Hydrator).to receive(:hydrate).and_return(records)

      expect(User.order(:name).to_a.map(&:name)).to eq(%w[Ada Zed])
      expect(User.order(name: :desc).to_a.map(&:name)).to eq(%w[Zed Ada])
    end
  end
end
