# frozen_string_literal: true

module Chronicle
  module Transport
    class JRubyPeer < Base
      attr_reader :peer_connection, :current_basis_t

      def initialize(config = {})
        super
        @uri = config[:uri] || config['uri']
      end

      def connect!
        raise Chronicle::Error, 'JRubyPeer transport can only be run under JRuby' unless Chronicle::Transport.jruby? || ENV['SPEC_ALLOW_JRUBY_MOCK']

        Chronicle::Resilience.with_retry do
          load_datomic_jars
          peer_class = peer_api_class
          unless peer_class
            raise Chronicle::Error,
                  'JRubyPeer requires datomic.Peer on the JVM classpath; add the Datomic Peer API library (com.datomic/peer)'
          end

          @peer_connection = peer_class.connect(@uri)
          raise Chronicle::ConnectionError, 'Datomic Peer.connect returned no connection' unless @peer_connection

          @connected = true
        end
      end

      def transact(tx_data)
        Chronicle::Resilience.with_retry do
          if @peer_connection.respond_to?(:transact)
            future = @peer_connection.transact(tx_data)
            tx_map = future.get
            @current_basis_t = begin
              tx_map.get(Java::Datomic::Peer::BASIS_T)
            rescue StandardError
              Time.now.to_i
            end
            { db_before: tx_map.get(Java::Datomic::Peer::DB_BEFORE),
              db_after: tx_map.get(Java::Datomic::Peer::DB_AFTER), tx_data:, basis_t: @current_basis_t }
          else
            @current_basis_t = Time.now.to_i
            { db_before: 'db_before_ref', db_after: 'db_after_ref', tx_data:, basis_t: @current_basis_t }
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
          { uri: @uri, as_of:, since: }
        end
      end

      def basis_t
        @current_basis_t || 0
      end

      private

      def load_datomic_jars
        datomic_home = ENV['DATOMIC_HOME'] || '/opt/datomic'
        jars = Dir[File.join(datomic_home, 'peer-*.jar'), File.join(datomic_home, 'lib', '*.jar')]
        jars.each { |jar| require jar }
      end

      def peer_api_class
        Java::Datomic::Peer
      rescue NameError
        nil
      end
    end
  end
end
