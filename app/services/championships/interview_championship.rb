module Championships
  class InterviewChampionship
    ROUNDS = [
      {
        round: 1,
        name: "Programming Fundamentals & Memory Model",
        question: "In Ruby, why does modifying a string inside an array mutate all references to that string unless dup or freeze is used?",
        options: [
          { text: "Variables in Ruby hold references (pointers) to heap objects, not copies of values.", correct: true },
          { text: "Ruby variables are stored on the call stack and cloned automatically.", correct: false },
          { text: "Strings in Ruby are immutable primitives like symbols.", correct: false }
        ],
        competency: "depth"
      },
      {
        round: 2,
        name: "Data Structures & Algorithms",
        question: "You need to find if two numbers in a sorted array sum to target T in O(n) time and O(1) space. Which technique should you choose?",
        options: [
          { text: "Two Pointers starting at opposite ends (left = 0, right = n-1) adjusting inward.", correct: true },
          { text: "Nested loops comparing every pair of numbers.", correct: false },
          { text: "Hash map storing complements (uses O(n) extra space).", correct: false }
        ],
        competency: "problem_solving"
      },
      {
        round: 3,
        name: "SQL & Query Optimization",
        question: "When should you use a PostgreSQL Partial Index (WHERE active = true) instead of an ordinary B-tree index?",
        options: [
          { text: "When queries filter on a highly skewed condition and you want to index only a small fraction of rows, saving RAM and disk I/O.", correct: true },
          { text: "When you want to index all NULL values exclusively.", correct: false },
          { text: "When table has fewer than 10 rows.", correct: false }
        ],
        competency: "technical_accuracy"
      },
      {
        round: 4,
        name: "Ruby & Rails Architecture",
        question: "How does Zeitwerk autoloading resolve constants in Rails 8 without causing race conditions in multi-threaded Puma workers?",
        options: [
          { text: "It eagerly preloads code at boot in production, freezing the namespace so no thread triggers on-demand const_missing.", correct: true },
          { text: "It uses Ruby Mutex locks on every method call.", correct: false },
          { text: "It executes all controller actions sequentially on a single thread.", correct: false }
        ],
        competency: "architecture"
      },
      {
        round: 5,
        name: "PostgreSQL Internals & MVCC",
        question: "Why does PostgreSQL create a brand new tuple version on every UPDATE, and what role does autovacuum play?",
        options: [
          { text: "Multi-Version Concurrency Control (MVCC) ensures readers never block writers; autovacuum reclaims dead tuple disk space and prevents transaction ID wraparound.", correct: true },
          { text: "It creates backups in case of power failure.", correct: false },
          { text: "It defragments memory for RAM caching.", correct: false }
        ],
        competency: "depth"
      },
      {
        round: 6,
        name: "Redis & Sidekiq Queues",
        question: "A background job makes an external API charge. If the worker container is abruptly SIGKILL'd during execution, how do you prevent double charging when Sidekiq retries?",
        options: [
          { text: "Make the job strictly idempotent using an Idempotency Key passed to the payment gateway and tracked in the database.", correct: true },
          { text: "Disable Sidekiq retries completely (sidekiq_options retry: 0).", correct: false },
          { text: "Rely on Redis in-memory atomic increments without database records.", correct: false }
        ],
        competency: "trade_offs"
      },
      {
        round: 7,
        name: "Frontend & Reactive DOM (Hotwire)",
        question: "What is the primary difference between Turbo Frames and Turbo Streams in modern Rails applications?",
        options: [
          { text: "Turbo Frames scope updates to a single matching container ID; Turbo Streams can mutate multiple arbitrary targets via 7 granular DOM actions (append, prepend, etc.).", correct: true },
          { text: "Turbo Frames use React; Turbo Streams use Angular.", correct: false },
          { text: "Turbo Streams only work over WebSockets.", correct: false }
        ],
        competency: "technical_accuracy"
      },
      {
        round: 8,
        name: "Application & Network Security",
        question: "Why is CSRF protection required even if your application uses secure, HttpOnly session cookies?",
        options: [
          { text: "Browsers automatically attach cookies to cross-origin requests; without CSRF token verification, a malicious site can forge unauthorized state-changing requests.", correct: true },
          { text: "HttpOnly cookies can be read by JavaScript.", correct: false },
          { text: "CSRF encrypts the request payload.", correct: false }
        ],
        competency: "security_awareness"
      },
      {
        round: 9,
        name: "Distributed System Design",
        question: "In a high-scale social network, why is 'fan-out on write' insufficient for celebrity accounts with 50 million followers, and how do you resolve it?",
        options: [
          { text: "Writing 50M records per post causes massive write amplification; resolve with hybrid fan-out (fan-out on read/merge at query for celebrities).", correct: true },
          { text: "Delete celebrity posts after 5 minutes.", correct: false },
          { text: "Store all 50M posts in a single text file.", correct: false }
        ],
        competency: "performance_awareness"
      },
      {
        round: 10,
        name: "Production Incident Debugging",
        question: "You observe API P99 latency jump from 30ms to 9,000ms while CPU remains at 5%. Database active connections are maxed at pool limit. What is the diagnosis?",
        options: [
          { text: "Connection Pool Exhaustion: Threads are blocked waiting to checkout a database connection from the pool, idling without CPU consumption.", correct: true },
          { text: "Infinite loop in Ruby code burning CPU.", correct: false },
          { text: "DNS resolution loop.", correct: false }
        ],
        competency: "debugging"
      },
      {
        round: 11,
        name: "Architectural Defense & Trade-offs",
        question: "When should an engineering team choose a well-modularized Rails Monolith over Microservices for a scaling business?",
        options: [
          { text: "When organizational domain boundaries are still evolving and the team wants single-deployment simplicity, ACID transactions, and zero network serialization overhead.", correct: true },
          { text: "Microservices are always better regardless of team size.", correct: false },
          { text: "Monoliths cannot handle more than 100 users.", correct: false }
        ],
        competency: "trade_offs"
      },
      {
        round: 12,
        name: "Rapid Fire Engineering Principles",
        question: "What does the Dependency Inversion Principle (the D in SOLID) require in software design?",
        options: [
          { text: "High-level modules should not depend on low-level modules; both should depend on abstractions (interfaces / duck-typed protocols).", correct: true },
          { text: "Every class must inherit from a parent class.", correct: false },
          { text: "Controllers must call database models directly without service objects.", correct: false }
        ],
        competency: "communication"
      }
    ].freeze

    def self.all_rounds
      ROUNDS
    end

    def self.round(number)
      ROUNDS.find { |r| r[:round] == number.to_i }
    end
  end
end
