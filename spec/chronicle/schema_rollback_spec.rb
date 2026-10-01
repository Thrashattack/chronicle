# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Datomic Schema Rollbacks and Deprecations" do
  describe Chronicle::Schema do
    it "generates an attribute drop datom that alters :db/ident to deprecated namespace" do
      datom = described_class.drop_attribute_datom(:user, :email, "20261001")

      expect(datom[":db/id"]).to eq(":user/email")
      expect(datom[":db/ident"]).to eq(":deprecated.user.20261001/email")
      expect(datom[":db/doc"]).to include("DEPRECATED and dropped")
    end

    it "generates a deprecation documentation datom" do
      datom = described_class.deprecate_attribute_datom(:user, :email, reason: "Replaced by user_emails table")

      expect(datom[":db/id"]).to eq(":user/email")
      expect(datom[":db/doc"]).to eq("DEPRECATED: Replaced by user_emails table")
    end

    it "generates a rename attribute datom altering :db/ident" do
      datom = described_class.rename_attribute_datom(:user, :old_email, :email)

      expect(datom[":db/id"]).to eq(":user/old_email")
      expect(datom[":db/ident"]).to eq(":user/email")
    end
  end
end
