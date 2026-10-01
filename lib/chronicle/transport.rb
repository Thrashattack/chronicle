# frozen_string_literal: true

require_relative 'transport/base'
require_relative 'transport/cruby_client'
require_relative 'transport/jruby_client'
require_relative 'transport/jruby_peer'

module Chronicle
  module Transport
    class << self
      def build(config = {})
        return JRubyPeer.new(config) if config[:transport].to_s == 'peer' || config['transport'].to_s == 'peer'

        if jruby?
          JRubyClient.new(config)
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
