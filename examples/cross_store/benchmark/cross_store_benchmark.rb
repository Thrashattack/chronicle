# frozen_string_literal: true

require "benchmark"
require_relative "../config/environment"

class CrossStoreBenchmark
  def initialize(iterations: Integer(ENV.fetch("ITERATIONS", 10)))
    @iterations = iterations
  end

  def run
    puts "Cross-store benchmark (#{@iterations} iterations)"
    puts "Datomic customer -> SQLite purchase"

    customer = DatomicCustomer.first || DatomicCustomer.create!(name: "Benchmark Customer", email: "benchmark@example.test")

    coordinated = Benchmark.realtime do
      @iterations.times do |index|
        Chronicle::TransactionCoordinator.transaction do |transaction|
          transaction.datomic(customer)
          transaction.sqlite do
            Purchase.create!(customer_id: customer.id, description: "Purchase #{index}", amount_cents: index + 1)
          end
        end
      end
    end

    sqlite_only = Benchmark.realtime do
      @iterations.times do |index|
        Purchase.create!(customer_id: customer.id, description: "SQLite #{index}", amount_cents: index + 1)
      end
    end

    print_result("coordinated", coordinated)
    print_result("sqlite-only", sqlite_only)
  end

  private

  def print_result(label, elapsed)
    puts format("%-14s %8.3f s  %8.2f writes/s", label, elapsed, @iterations / elapsed)
  end
end

CrossStoreBenchmark.new.run if $PROGRAM_NAME == __FILE__
