# frozen_string_literal: true

require "spec_helper"

RSpec.describe Chronicle::Relation do
  let(:dummy_model) do
    Class.new(ActiveRecord::Base) do
      self.table_name = "users"
      include Chronicle::Model

      datomic_attribute :name, :string
      datomic_attribute :email, :string
    end
  end

  describe "#as_of" do
    it "attaches as_of timestamp to time_travel_options" do
      timestamp = Time.now
      rel = dummy_model.all.extending(Chronicle::Model::TimeTravelExtension).as_of(timestamp)
      expect(rel.time_travel_options[:as_of]).to eq(timestamp)
    end
  end

  describe "#since" do
    it "attaches since timestamp to time_travel_options" do
      timestamp = 1.day.ago
      rel = dummy_model.all.extending(Chronicle::Model::TimeTravelExtension).since(timestamp)
      expect(rel.time_travel_options[:since]).to eq(timestamp)
    end
  end
end
