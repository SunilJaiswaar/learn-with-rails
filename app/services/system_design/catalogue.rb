module SystemDesign
  class Catalogue
    CHALLENGES = [
      {
        slug: "url-shortener",
        title: "URL Shortener (TinyURL)",
        icon: "🔗",
        tagline: "100 Million URLs · 25,000 RPS Peak",
        difficulty: "Intermediate",
        xp_reward: 350,
        functional_requirements: [
          "Given a long URL, return a unique 7-character short URL (Base62)",
          "Redirect short URL to long URL in < 30ms (P99)",
          "Custom aliases and expiration dates"
        ],
        non_functional_requirements: [
          "High availability (99.99%) — redirects must not fail",
          "Read-heavy: 10:1 read-to-write ratio",
          "Low latency: < 30ms P99 redirection"
        ],
        initial_components: %w[client dns app_servers postgresql_primary],
        available_components: %w[
          client dns cdn load_balancer api_gateway app_servers
          postgresql_primary postgresql_replicas redis_cache message_queue
          workers object_storage monitoring
        ],
        traffic_rps: 5000,
        target_rps: 25000,
        max_acceptable_latency: 50,
        max_acceptable_error: 0.5,
        available_failures: [
          { id: "redis_down", name: "Redis Cache Outage", description: "Cache crashes. All reads bypass cache and hit PostgreSQL directly." },
          { id: "traffic_spike_10x", name: "Viral Traffic Spike (10x)", description: "Traffic explodes from 5,000 to 50,000 requests per second." },
          { id: "db_slow", name: "Disk I/O Saturation on Primary", description: "Database storage IOPS maxed out; queries take 800ms+." }
        ],
        architectural_solutions: [
          "Introduce CDN for static routing and GeoDNS",
          "Place a redundant Load Balancer in front of clustered Rails app servers",
          "Deploy Redis Cache for the top 20% hottest URLs (80/20 Pareto principle)",
          "Add PostgreSQL Read Replicas to offload redirection reads from Primary"
        ]
      },
      {
        slug: "real-time-chat",
        title: "Real-Time Chat (Slack/Discord)",
        icon: "💬",
        tagline: "500,000 Concurrent WebSockets · Sub-100ms Delivery",
        difficulty: "Advanced",
        xp_reward: 450,
        functional_requirements: [
          "One-on-one and group channels with live message delivery",
          "Online presence indicator (online, away, offline)",
          "Persistent message history and search"
        ],
        non_functional_requirements: [
          "Sub-100ms end-to-end message latency across the globe",
          "Persistent state across client reconnects",
          "Horizontal scalability of WebSocket connection gateways"
        ],
        initial_components: %w[client dns app_servers postgresql_primary],
        available_components: %w[
          client dns cdn load_balancer api_gateway app_servers
          postgresql_primary postgresql_replicas redis_cache message_queue
          workers object_storage monitoring
        ],
        traffic_rps: 12000,
        target_rps: 40000,
        max_acceptable_latency: 100,
        max_acceptable_error: 0.2,
        available_failures: [
          { id: "ws_server_crash", name: "WebSocket Gateway Crash", description: "50,000 socket connections drop simultaneously and attempt to reconnect." },
          { id: "redis_pubsub_backlog", name: "Pub/Sub Fan-out Backpressure", description: "A message sent to a 100,000-user channel causes severe queue lag." },
          { id: "pool_exhaustion", name: "Database Connection Pool Exhaustion", description: "ActiveRecord connections exhausted as every client queries message history on reconnect." }
        ],
        architectural_solutions: [
          "Deploy Anycast DNS and Layer 4 TCP Load Balancers for WebSocket affinity",
          "Separate WebSocket Gateway servers from REST API app servers",
          "Use Redis Pub/Sub or Kafka cluster to broadcast messages between server instances",
          "Store message history in partitionable storage with read replicas"
        ]
      },
      {
        slug: "social-feed",
        title: "Social Network Feed (Instagram/Twitter)",
        icon: "📸",
        tagline: "Celebrity Fan-out · 100k Posts/sec · Media Storage",
        difficulty: "Master",
        xp_reward: 500,
        functional_requirements: [
          "Post photos, videos, and captions",
          "Follow users and view an aggregated reverse-chronological timeline",
          "Instant timeline updates from followed accounts"
        ],
        non_functional_requirements: [
          "Feed generation within 150ms",
          "Handle celebrity fan-out (user with 50M followers posts an update)",
          "High availability with eventual consistency for feed reads"
        ],
        initial_components: %w[client dns app_servers postgresql_primary object_storage],
        available_components: %w[
          client dns cdn load_balancer api_gateway app_servers
          postgresql_primary postgresql_replicas redis_cache message_queue
          workers object_storage monitoring
        ],
        traffic_rps: 20000,
        target_rps: 65000,
        max_acceptable_latency: 120,
        max_acceptable_error: 0.1,
        available_failures: [
          { id: "celebrity_fanout_storm", name: "Celebrity Post Fan-out Storm", description: "A user with 20M followers posts; background workers choked trying to write 20M timeline entries." },
          { id: "s3_rate_limit", name: "Object Storage Hotspotting", description: "Viral media file causes S3 503 Slow Down rate limit." },
          { id: "db_write_bottleneck", name: "Write Amplification on Database", description: "Primary DB lock contention on user timelines table." }
        ],
        architectural_solutions: [
          "Hybrid fan-out: Fan-out on write for regular users; fan-out on read (merge-at-query) for celebrities",
          "Place CloudFront CDN in front of Object Storage (S3) with edge caching for media assets",
          "Store user home timelines in Redis Sorted Sets (ZADD with timestamp score)",
          "Decouple post processing with Kafka/Sidekiq background worker clusters"
        ]
      },
      {
        slug: "payment-platform",
        title: "Payment Gateway (Stripe/PayPal)",
        icon: "💳",
        tagline: "Zero Double Debits · Exact-Once Semantics · 99.999% SLA",
        difficulty: "Master",
        xp_reward: 600,
        functional_requirements: [
          "Process credit card charges and bank transfers with external providers",
          "Guarantee exactly-once execution via Idempotency Keys",
          "Maintain double-entry ledger with immutable audit trail"
        ],
        non_functional_requirements: [
          "Strict Consistency (ACID) over Eventual Consistency for financial ledgers",
          "Zero tolerance for double billing or lost transactions",
          "Graceful degradation when external bank networks timeout"
        ],
        initial_components: %w[client dns app_servers postgresql_primary],
        available_components: %w[
          client dns cdn load_balancer api_gateway app_servers
          postgresql_primary postgresql_replicas redis_cache message_queue
          workers object_storage monitoring
        ],
        traffic_rps: 3000,
        target_rps: 15000,
        max_acceptable_latency: 80,
        max_acceptable_error: 0.001,
        available_failures: [
          { id: "bank_timeout_storm", name: "External Bank Gateway Timeout", description: "Acquiring bank takes 15 seconds to reply; worker threads exhausted holding connections." },
          { id: "network_partition", name: "Network Partition Between App & DB", description: "App servers lose heartbeat to primary DB during transaction commit." },
          { id: "duplicate_request_burst", name: "Customer Double-Click / Retry Burst", description: "User retries payment 5 times in 200ms when UI stutters." }
        ],
        architectural_solutions: [
          "Idempotency layer: Store idempotency key + request hash in Redis with atomic SETNX",
          "Circuit Breaker pattern on external banking APIs to fail fast when downstream is degraded",
          "Transactional Outbox pattern: Write payment intent and ledger entry in single DB transaction, then async worker publishes to queue",
          "Pessimistic row locking (SELECT ... FOR UPDATE) on account balances"
        ]
      }
    ].freeze

    def self.all
      CHALLENGES
    end

    def self.find_by_slug(slug)
      CHALLENGES.find { |c| c[:slug] == slug.to_s }
    end
  end
end
