module DomainEvents
  module Delivery
    class Drain
      def self.call
        counts = Dispatch.call
        # Drain ordered successors promptly. The sweep recovers delayed retries.
        Wake.call if counts.values_at(:processed, :ignored, :skipped).compact.sum.positive?
        counts
      end
    end
  end
end
