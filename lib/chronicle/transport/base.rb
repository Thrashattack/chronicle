# frozen_string_literal: true

module Chronicle
  module Transport
    class Base
      attr_reader :config

      def initialize(config = {})
        @config = config
      end

      def connect!
        raise NotImplementedError, "#{self.class}#connect! must be implemented"
      end

      def transact(tx_data)
        raise NotImplementedError, "#{self.class}#transact must be implemented"
      end

      def q(query, *args)
        raise NotImplementedError, "#{self.class}#q must be implemented"
      end

      def db(as_of: nil, since: nil)
        raise NotImplementedError, "#{self.class}#db must be implemented"
      end

      def basis_t
        raise NotImplementedError, "#{self.class}#basis_t must be implemented"
      end
    end
  end
end
