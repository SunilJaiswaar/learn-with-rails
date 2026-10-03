module Incidents
  class Catalogue
    INCIDENTS = [
      {
        slug: "n-plus-one-firestorm",
        title: "🚨 8-Second API Outage: N+1 Query Firestorm",
        severity: "CRITICAL",
        category: "Database & Performance",
        xp_reward: 250,
        symptom: "Customer checkout dashboard API /api/v1/orders has degraded to 8.4 seconds under normal traffic. Database CPU spiked to 92%.",
        telemetry: {
          "Endpoint": "GET /api/v1/orders",
          "P99 Latency": "8,420 ms (Normal: 45 ms)",
          "Database CPU": "92%",
          "Database Queries": "1,201 queries per HTTP request",
          "Active Connections": "48 / 50"
        },
        logs: [
          "[00:00.001] Started GET \"/api/v1/orders\" for 198.51.100.42 at 2026-10-03 14:02:11 +0000",
          "[00:00.004] Processing by Api::V1::OrdersController#index as JSON",
          "[00:00.012] Order Load (8.2ms)  SELECT * FROM orders WHERE user_id = 42 ORDER BY created_at DESC LIMIT 50",
          "[00:00.019] LineItem Load (0.4ms)  SELECT * FROM line_items WHERE order_id = 1001",
          "[00:00.024] Product Load (0.3ms)   SELECT * FROM products WHERE id = 401",
          "[00:00.029] LineItem Load (0.4ms)  SELECT * FROM line_items WHERE order_id = 1002",
          "[00:00.035] Product Load (0.3ms)   SELECT * FROM products WHERE id = 402",
          "... [1,196 identical repetitive SQL queries omitted] ...",
          "[00:08.418] Completed 200 OK in 8418ms (Views: 120.4ms | ActiveRecord: 8290.1ms)"
        ].join("\n"),
        code_snippet: "class Api::V1::OrdersController < ApplicationController\n  def index\n    @orders = current_user.orders.limit(50)\n    render json: @orders.as_json(include: { line_items: { include: :product } })\n  end\nend",
        options: [
          { id: "add_sleep", text: "Add sleep(0.1) between queries to lower database load", correct: false, reason: "Sleeping makes the request even slower! It doesn't reduce query count." },
          { id: "eager_loading", text: "Add eager loading: current_user.orders.includes(line_items: :product).limit(50)", correct: true, reason: "Collapses 1,201 queries into 3 efficient queries using SQL IN clauses. Latency drops from 8.4s to 24ms!" },
          { id: "restart_postgres", text: "Restart the PostgreSQL server to clear active query buffers", correct: false, reason: "A restart clears connections but doesn't fix the application N+1 query loop." }
        ],
        explanation: "In Rails, associations are lazily evaluated by default. Iterating through 50 orders and fetching line items and products in a loop produces 1 + N + (N * M) queries. Using .includes eager-loads all associated records in 3 queries."
      },
      {
        slug: "connection-pool-exhaustion",
        title: "🚨 ConnectionTimeoutError: Database Pool Saturated",
        severity: "HIGH",
        category: "Concurrency & Infrastructure",
        xp_reward: 200,
        symptom: "Users getting HTTP 500 errors during traffic spikes. Logs show ActiveRecord::ConnectionTimeoutError: could not obtain a connection from the pool within 5.000 seconds.",
        telemetry: {
          "Error Rate": "41.2% (HTTP 500)",
          "Puma Worker Threads": "25 threads per worker (3 workers = 75 total threads)",
          "Database Pool Setting": "RAILS_MAX_THREADS=25, DB_POOL=5",
          "Active Pool Connections": "5 / 5 (100% saturated)",
          "Threads Waiting for Connection": "20 threads blocked"
        },
        logs: [
          "ActiveRecord::ConnectionTimeoutError: could not obtain a connection from the pool within 5.000 seconds (waited 5.002s); all 5 connections in use",
          "  from activerecord-8.1/lib/active_record/connection_adapters/abstract/connection_pool.rb:234:in `acquire_connection'",
          "  from activerecord-8.1/lib/active_record/connection_adapters/abstract/connection_pool.rb:601:in `checkout'",
          "  from activerecord-8.1/lib/active_record/connection_handling.rb:333:in `connection'"
        ].join("\n"),
        code_snippet: "# config/database.yml\ndefault: &default\n  adapter: postgresql\n  pool: <%= ENV.fetch('DB_POOL', 5) %>\n\n# config/puma.rb\nmax_threads = ENV.fetch('RAILS_MAX_THREADS', 25)\nthreads max_threads, max_threads",
        options: [
          { id: "increase_timeout", text: "Increase checkout_timeout to 60 seconds so threads wait longer", correct: false, reason: "Increasing timeout just makes HTTP requests hang for 60 seconds before failing!" },
          { id: "align_pool_size", text: "Align database connection pool size with Puma thread count (DB_POOL=25)", correct: true, reason: "Each Puma thread executing a DB query needs its own connection from the pool. Pool size must be >= max_threads." },
          { id: "disable_pooling", text: "Open a brand new TCP database connection on every request", correct: false, reason: "TCP handshake and TLS negotiation on every request exhausts OS sockets and destroys performance." }
        ],
        explanation: "In multi-threaded Rails applications, every thread doing database work requires a connection from the ActiveRecord pool. If you have 25 Puma threads but only 5 pool connections, 20 threads will block and eventually timeout after 5 seconds."
      },
      {
        slug: "memory-leak-worker",
        title: "🚨 Out of Memory: Sidekiq Process Crashes Every 2 Hours",
        severity: "HIGH",
        category: "Ruby Internals & Garbage Collection",
        xp_reward: 200,
        symptom: "Background worker container is killed by Linux kernel OOM (Out Of Memory) killer on a steady 2-hour schedule. Memory graph shows linear staircase climbing.",
        telemetry: {
          "Process RSS Memory": "1,940 MB / 2,048 MB limit (95%)",
          "GC Major Runs": "1,420 runs (Heap slots: 18,400,000)",
          "Kernel Signal": "SIGKILL (Exit code 137 - OOM)",
          "Queue Backlog": "14,200 pending jobs"
        },
        logs: [
          "[14:22:01] kernel: [142091.120] Out of memory: Killed process 8192 (bundle) total-vm:2840192kB, anon-rss:1984210kB",
          "[14:22:02] sidekiq: [INFO] Worker process terminated unexpectedly with signal 9",
          "[14:22:03] kubernetes: Container sidekiq-worker restarted (restarts: 12)"
        ].join("\n"),
        code_snippet: "class ExportUserDataJob\n  include Sidekiq::Job\n  @@exported_cache = [] # Class variable\n\n  def perform(user_id)\n    user = User.find(user_id)\n    data = user.generate_archive\n    @@exported_cache << data # Accretion without eviction\n    S3Uploader.upload(data)\n  end\nend",
        options: [
          { id: "increase_container_ram", text: "Double Kubernetes container RAM limit from 2GB to 8GB", correct: false, reason: "A memory leak will eventually consume 8GB, 16GB, or 32GB. Increasing RAM only delays the crash!" },
          { id: "remove_class_variable", text: "Remove class variable @@exported_cache and let garbage collector free data after each job", correct: true, reason: "Class variables persist for the entire lifetime of the Ruby process. Removing it allows Ruby GC to reclaim heap slots!" },
          { id: "run_gc_start", text: "Invoke GC.start manually after every single job", correct: false, reason: "GC.start stops the world and burns CPU, but cannot free objects still referenced by @@exported_cache!" }
        ],
        explanation: "Class variables (@@var) and module constants are rooted in Ruby's ObjectSpace and are NEVER collected by the Garbage Collector. Storing per-job data in class variables creates a classic unbounded memory leak."
      },
      {
        slug: "race-condition-double-charge",
        title: "🚨 Financial Anomaly: Customer Balance Dropped to -$500",
        severity: "CRITICAL",
        category: "Concurrency & Data Integrity",
        xp_reward: 250,
        symptom: "Customer made 5 rapid concurrent withdrawal requests of $100 with an initial balance of $100. Account balance is now -$400.",
        telemetry: {
          "Initial Balance": "$100.00",
          "Requested Withdrawals": "5 x $100.00",
          "Concurrent Execution": "Simultaneous Puma threads at 14:01:02.102",
          "Final Recorded Balance": "-$400.00 (Illegal State)"
        },
        logs: [
          "[Thread-1] SELECT balance FROM accounts WHERE id = 1 -> $100",
          "[Thread-2] SELECT balance FROM accounts WHERE id = 1 -> $100",
          "[Thread-3] SELECT balance FROM accounts WHERE id = 1 -> $100",
          "[Thread-1] Balance $100 >= $100: APPROVED. UPDATE accounts SET balance = 0 WHERE id = 1",
          "[Thread-2] Balance $100 >= $100: APPROVED. UPDATE accounts SET balance = -100 WHERE id = 1",
          "[Thread-3] Balance $100 >= $100: APPROVED. UPDATE accounts SET balance = -200 WHERE id = 1"
        ].join("\n"),
        code_snippet: "class WalletService\n  def self.withdraw(account, amount)\n    if account.balance >= amount\n      account.update!(balance: account.balance - amount)\n      PaymentGateway.charge(account, amount)\n    else\n      raise InsufficientFundsError\n    end\n  end\nend",
        options: [
          { id: "check_in_memory", text: "Check balance in an in-memory Ruby mutex inside the controller", correct: false, reason: "Ruby Mutex only synchronizes threads within one process! It does not work across multiple Puma workers or servers." },
          { id: "pessimistic_locking", text: "Use Pessimistic Row Locking (account.with_lock) + DB check constraint (balance >= 0)", correct: true, reason: "with_lock acquires a SELECT ... FOR UPDATE database lock on the row, serializing concurrent writes at the ACID level!" },
          { id: "delayed_job", text: "Move withdrawals to a delayed background job", correct: false, reason: "Workers can still process jobs concurrently, causing the exact same race condition." }
        ],
        explanation: "Check-then-act operations without database-level concurrency control (pessimistic locking via with_lock or optimistic locking via lock_version) suffer from Time-of-Check to Time-of-Use (TOCTOU) race conditions."
      }
    ].freeze

    def self.all
      INCIDENTS
    end

    def self.find_by_slug(slug)
      INCIDENTS.find { |i| i[:slug] == slug.to_s }
    end
  end
end
