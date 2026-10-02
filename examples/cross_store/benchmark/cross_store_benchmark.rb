# frozen_string_literal: true

require "benchmark"
require_relative "../config/environment"

class CrossStoreBenchmark
  MIN_COORDINATED_RATIO = 0.5

  def initialize(iterations: Integer(ENV.fetch("ITERATIONS", 1_000)))
    @iterations = iterations
  end

  def run
    puts "Cross-store benchmark (#{@iterations} iterations)"
    puts "Datomic customer -> SQLite purchase"

    customer = DatomicCustomer.first || DatomicCustomer.create!(name: "Benchmark Customer", email: "benchmark@example.test")

    coordinated = Benchmark.realtime do
      Chronicle::TransactionCoordinator.transact(transport: DatomicCustomer.chronicle_transport) do |transaction|
        transaction.datomic(customer)
        transaction.sqlite do
          Purchase.transaction do
            @iterations.times do |index|
              Purchase.create!(customer_id: customer.id, description: "Purchase #{index}", amount_cents: index + 1)
            end
          end
        end
      end
    end

    sqlite_only = Benchmark.realtime do
      Purchase.transaction do
        @iterations.times do |index|
          Purchase.create!(customer_id: customer.id, description: "SQLite #{index}", amount_cents: index + 1)
        end
      end
    end

    print_result("coordinated", coordinated)
    print_result("sqlite-only", sqlite_only)

    coordinated_rate = @iterations / coordinated
    sqlite_rate = @iterations / sqlite_only
    minimum_rate = sqlite_rate * MIN_COORDINATED_RATIO
    raise "coordinated throughput #{coordinated_rate.round(2)} writes/s is below 50% of SQLite-only #{sqlite_rate.round(2)} writes/s" if coordinated_rate < minimum_rate

    puts format("threshold     PASS (%.2f%% of sqlite-only)", coordinated_rate / sqlite_rate * 100)
  end

  private

  def print_result(label, elapsed)
    puts format("%-14s %8.3f s  %8.2f writes/s", label, elapsed, @iterations / elapsed)
  end
end

CrossStoreBenchmark.new.run if $PROGRAM_NAME == __FILE__
