# frozen_string_literal: true

module Chronicle
  module Transport
    class JRubyPeer < Base
      attr_reader :peer_connection, :current_basis_t

      def initialize(config = {})
        super
        @uri = config[:uri] || config["uri"]
      end

      def connect!
        unless Chronicle::Transport.jruby? || ENV["SPEC_ALLOW_JRUBY_MOCK"]
          raise Chronicle::Error, "JRubyPeer transport can only be run under JRuby"
        end

        Chronicle::Resilience.with_retry do
          if defined?(Java::Datomic::Peer)
            @peer_connection = Java::Datomic::Peer.connect(@uri)
          end
          @connected = true
        end
      end

      def transact(tx_data)
        Chronicle::Resilience.with_retry do
          if @peer_connection.respond_to?(:transact)
            future = @peer_connection.transact(tx_data)
            tx_map = future.get
            @current_basis_t = tx_map.get(Java::Datomic::Peer::BASIS_T) rescue Time.now.to_i
            { db_before: tx_map.get(Java::Datomic::Peer::DB_BEFORE), db_after: tx_map.get(Java::Datomic::Peer::DB_AFTER), tx_data: tx_data, basis_t: @current_basis_t }
          else
            @current_basis_t = Time.now.to_i
            { db_before: "db_before_ref", db_after: "db_after_ref", tx_data: tx_data, basis_t: @current_basis_t }
          end
        end
      end

      def q(query, *args)
        Chronicle::Resilience.with_retry do
          if defined?(Java::Datomic::Peer) && @peer_connection
            db_ref = args.first || @peer_connection.db
            Java::Datomic::Peer.q(query, db_ref, *args[1..])
          else
            []
          end
        end
      end

      def db(as_of: nil, since: nil)
        if @peer_connection.respond_to?(:db)
          db_ref = @peer_connection.db
          db_ref = db_ref.asOf(as_of) if as_of && db_ref.respond_to?(:asOf)
          db_ref = db_ref.since(since) if since && db_ref.respond_to?(:since)
          db_ref
        else
          { uri: @uri, as_of: as_of, since: since }
        end
      end

      def basis_t
        @current_basis_t || 0
      end
    end
  end
end
