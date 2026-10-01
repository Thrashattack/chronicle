# frozen_string_literal: true

require "spec_helper"

RSpec.describe Chronicle do
  it "has a version number" do
    expect(Chronicle::VERSION).not_to be nil
  end

  describe ".configure" do
    it "sets configuration parameters" do
      Chronicle.configure do |config|
        config.uri = "datomic:dev://localhost:4334/chronicle_test"
        config.client_endpoint = "http://localhost:8989"
      end

      expect(Chronicle.configuration.uri).to eq("datomic:dev://localhost:4334/chronicle_test")
      expect(Chronicle.configuration.client_endpoint).to eq("http://localhost:8989")
    end
  end

  describe Chronicle::Transport do
    it "detects current Ruby engine" do
      if RUBY_ENGINE == "jruby"
        expect(Chronicle::Transport.jruby?).to be true
      else
        expect(Chronicle::Transport.jruby?).to be false
      end
    end

    it "instantiates CRubyClient for non-JRuby runtimes" do
      transport = Chronicle::Transport.build(client_endpoint: "http://localhost:8989")
      unless Chronicle::Transport.jruby?
        expect(transport).to be_a(Chronicle::Transport::CRubyClient)
      end
    end
  end

  describe Chronicle::Schema do
    it "generates valid Datomic schema definition hashes" do
      schema = Chronicle::Schema.create_attribute(:user, :email, :string, unique: :identity)
      expect(schema[":db/ident"]).to eq(":user/email")
      expect(schema[":db/valueType"]).to eq(":db.type/string")
      expect(schema[":db/unique"]).to eq(":db.unique/identity")
    end
  end
end
