# frozen_string_literal: true

require_relative 'transport/base'
require_relative 'transport/cruby_client'
require_relative 'transport/jruby_peer'

module Chronicle
  module Transport
    class << self
      def build(config = {})
        if jruby?
          JRubyPeer.new(config)
        else
          CRubyClient.new(config)
        end
      end

      def client(config = {})
        @client ||= build(config)
      end

      def jruby?
        RUBY_ENGINE == 'jruby'
      end
    end
  end
end
