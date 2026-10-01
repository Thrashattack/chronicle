# frozen_string_literal: true

require "spec_helper"

RSpec.describe Chronicle::Schema do
  describe ".define" do
    it "converts Active Record schema DSL into Datomic schema datoms" do
      datoms = described_class.define(:user) do |t|
        t.string :name, doc: "User display name"
        t.string :email, unique: :identity, index: true
        t.integer :age
        t.boolean :active
        t.ref :organization
        t.timestamps
      end

      expect(datoms.size).to eq(7)

      email_datom = datoms.find { |d| d[":db/ident"] == ":user/email" }
      expect(email_datom[":db/valueType"]).to eq(":db.type/string")
      expect(email_datom[":db/cardinality"]).to eq(":db.cardinality/one")
      expect(email_datom[":db/unique"]).to eq(":db.unique/identity")
      expect(email_datom[":db/index"]).to be(true)

      org_datom = datoms.find { |d| d[":db/ident"] == ":user/organization" }
      expect(org_datom[":db/valueType"]).to eq(":db.type/ref")

      created_at_datom = datoms.find { |d| d[":db/ident"] == ":user/created_at" }
      expect(created_at_datom[":db/valueType"]).to eq(":db.type/instant")
    end
  end
end
