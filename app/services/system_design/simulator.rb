module SystemDesign
  # Simulates high-scale traffic and failure modes against a chosen architecture (spec 13-18).
  class Simulator
    COMPONENTS_INFO = {
      "client" => { name: "Web / Mobile Clients", icon: "📱", cost: 0 },
      "dns" => { name: "GeoDNS / Route 53", icon: "🌐", cost: 50 },
      "cdn" => { name: "CloudFront CDN (Edge Cache)", icon: "⚡", cost: 250 },
      "load_balancer" => { name: "NLB / ALB (Load Balancer)", icon: "⚖️", cost: 120 },
      "api_gateway" => { name: "API Gateway (Rate Limiting & Auth)", icon: "🚪", cost: 180 },
      "app_servers" => { name: "Rails Application Cluster", icon: "💎", cost: 400 },
      "postgresql_primary" => { name: "PostgreSQL Primary (Leader)", icon: "🐘", cost: 500 },
      "postgresql_replicas" => { name: "PostgreSQL Read Replicas", icon: "👥", cost: 400 },
      "redis_cache" => { name: "Redis Cluster (Cache & Sessions)", icon: "🧠", cost: 200 },
      "message_queue" => { name: "Message Queue (Kafka / Sidekiq)", icon: "📬", cost: 180 },
      "workers" => { name: "Background Worker Fleet", icon: "⚙️", cost: 300 },
      "object_storage" => { name: "S3 Object Storage", icon: "📦", cost: 150 },
      "monitoring" => { name: "Datadog / Prometheus Observability", icon: "📊", cost: 120 }
    }.freeze

    # Throughput one Rails instance sustains.
    RPS_PER_APP_INSTANCE = 1_500

    # Spare capacity a load-balanced cluster is provisioned with, relative to
    # the challenge's own target RPS. A fixed ceiling cannot serve both a
    # 15k-RPS brief and a 65k-RPS one, so capacity is derived from the brief.
    AUTOSCALE_HEADROOM = 1.2

    # How much a "viral spike" failure multiplies incoming traffic by.
    TRAFFIC_SPIKE_MULTIPLIER = 10
    MIN_AUTOSCALE_INSTANCES = 8

    Result = Struct.new(
      :p99_latency_ms,
      :error_rate_percent,
      :app_cpu_percent,
      :db_connections_used,
      :db_connection_limit,
      :cache_hit_ratio_percent,
      :queue_depth,
      :monthly_cost,
      :bottlenecks,
      :verdict,
      :passed,
      :explanation,
      keyword_init: true
    )

    # How many instances the cluster may scale to: enough to serve the
    # challenge's stated target with headroom, so a sound architecture can meet
    # the brief while a 10x spike still saturates it.
    def autoscale_ceiling
      target = (@challenge[:target_rps] || @rps).to_i
      needed = ((target.to_f / RPS_PER_APP_INSTANCE) * AUTOSCALE_HEADROOM).ceil
      [ needed, MIN_AUTOSCALE_INSTANCES ].max
    end

    def initialize(challenge:, components:, rps:, active_failures: [])
      @challenge = challenge
      @components = Array(components).map(&:to_s).uniq
      @rps = [ rps.to_i, 100 ].max
      @active_failures = Array(active_failures).map(&:to_s)
    end

    def call
      bottlenecks = []

      has_cdn = @components.include?("cdn")
      has_lb = @components.include?("load_balancer")
      has_gateway = @components.include?("api_gateway")
      has_app = @components.include?("app_servers")
      has_db = @components.include?("postgresql_primary")
      has_replicas = @components.include?("postgresql_replicas")
      has_redis = @components.include?("redis_cache")
      has_queue = @components.include?("message_queue")
      has_workers = @components.include?("workers")

      # Monthly cost calculation
      cost = @components.sum { |c| COMPONENTS_INFO.dig(c, :cost) || 0 }

      # Base calculations.
      #
      # A traffic surge has to be applied before capacity is sized, otherwise
      # it cannot show up in CPU or connection-pool pressure — which is the
      # whole lesson the failure is meant to teach.
      effective_rps = @rps
      effective_rps *= TRAFFIC_SPIKE_MULTIPLIER if @active_failures.include?("traffic_spike_10x")
      cache_hit_ratio = 0.0

      if has_cdn
        # CDN absorbs static reads and edge queries
        effective_rps = (effective_rps * 0.7).round
      end

      if has_redis && !@active_failures.include?("redis_down")
        cache_hit_ratio = 0.82
      elsif @active_failures.include?("redis_down")
        bottlenecks << "💥 REDIS OUTAGE: Cache is down! Cache hit ratio collapsed to 0%. 100% of read traffic is slamming PostgreSQL primary!"
      end

      # App server capacity.
      #
      # A single instance serves ~1,500 RPS. A load balancer is what makes
      # horizontal scaling possible at all, so it raises the instance ceiling
      # rather than granting a fixed bump: without one you are pinned to a
      # single box no matter how much traffic arrives.
      #
      # The ceiling is deliberately above each challenge's target RPS, so a
      # well-designed architecture can actually clear the brief, while a 10x
      # spike still saturates it.
      app_instances = has_lb ? autoscale_ceiling : 1
      max_app_rps = app_instances * RPS_PER_APP_INSTANCE
      app_cpu = ((effective_rps.to_f / max_app_rps) * 100).round.clamp(5, 100)

      if app_cpu >= 90
        bottlenecks << if has_lb
                         "🔥 CPU SATURATION: Rails cluster at #{app_cpu}% CPU even " \
                         "fully scaled out (#{app_instances} instances). Shed load at " \
                         "the edge with a CDN, or cut work per request."
        else
                         "🔥 CPU SATURATION: Rails app servers at #{app_cpu}% CPU on a " \
                         "single instance. Add a Load Balancer so the cluster can " \
                         "scale horizontally."
        end
      end

      # DB load
      db_reads_rps = (effective_rps * (1.0 - cache_hit_ratio)).round
      db_connection_limit = 100
      db_conns_used = [ (db_reads_rps / 250) + 10, 10 ].max

      if has_replicas
        db_conns_used = (db_conns_used * 0.4).round
      else
        bottlenecks << "⚠️ SINGLE POINT OF FAILURE: All read and write queries sent to Primary DB. Add Read Replicas to divide load." if @rps > 10000
      end

      if db_conns_used > db_connection_limit
        bottlenecks << "🛑 DB POOL EXHAUSTION: Active connections (#{db_conns_used}) exceed pool limit (#{db_connection_limit}). ActiveRecord ConnectionTimeoutError thrown."
      end

      # Calculate latency and error rate based on components and active failures
      base_latency = 18.0

      # Architectural additions that improve latency
      base_latency -= 5 if has_cdn
      base_latency -= 6 if has_redis && !@active_failures.include?("redis_down")
      base_latency -= 3 if has_replicas

      # Penalties for bottlenecks
      base_latency += (app_cpu * 0.8) if app_cpu > 70
      base_latency += (db_conns_used * 1.5) if db_conns_used > 60

      # Failure mode penalties
      if @active_failures.include?("traffic_spike_10x")
        # The load itself was already applied above; this is the queueing cost.
        base_latency += 120
        bottlenecks << "🌊 #{TRAFFIC_SPIKE_MULTIPLIER}x TRAFFIC SURGE: Massive traffic " \
                       "spike. Servers struggling with incoming connection queue."
      end

      if @active_failures.include?("db_slow")
        base_latency += 350
        bottlenecks << "⏳ DB DISK I/O MAXED: Queries queueing up behind write locks. P99 latency degraded by 350ms+."
      end

      if @active_failures.include?("celebrity_fanout_storm")
        if has_queue && has_workers
          base_latency += 25
        else
          base_latency += 480
          bottlenecks << "💣 FAN-OUT STORM: Writing 20M timeline entries synchronously in web request threads crashed Puma workers! Decouple with Kafka/Sidekiq background fleet."
        end
      end

      if @active_failures.include?("bank_timeout_storm")
        if has_queue && has_gateway
          base_latency += 30
        else
          base_latency += 800
          bottlenecks << "💳 BANK TIMEOUT CASCADE: External payment provider latency tied up all Rails worker threads. Introduce Circuit Breaker and async message queues."
        end
      end

      # Compute final P99 latency
      p99_latency = [ base_latency.round, 8 ].max

      # Error rate
      error_rate = 0.0
      error_rate += 18.5 if app_cpu >= 98
      error_rate += 25.0 if db_conns_used > db_connection_limit
      error_rate += 12.0 if @active_failures.include?("redis_down") && !has_replicas
      error_rate += 15.0 if @active_failures.include?("bank_timeout_storm") && !has_queue

      error_rate = error_rate.clamp(0.0, 99.9).round(2)

      # Evaluate SLA against challenge requirements
      max_lat = @challenge[:max_acceptable_latency] || 50
      max_err = @challenge[:max_acceptable_error] || 0.5
      passed = (p99_latency <= max_lat) && (error_rate <= max_err) && (@rps >= @challenge[:target_rps])

      verdict = if passed
                  "OPTIMAL: All SLAs satisfied under production scale! Architecture is resilient."
      elsif bottlenecks.any?
                  "SLA BREACHED: Performance degraded. Inspect bottlenecks and re-architect."
      else
                  "VIABLE: System operational, but increase simulated RPS to target #{number_with_delimiter(@challenge[:target_rps])} to stress-test."
      end

      explanation = if passed
                      "Outstanding engineering! By pairing #{has_cdn ? 'CDN' : nil} #{has_lb ? 'Load Balancing' : nil} #{has_redis ? 'Redis Caching' : nil} and #{has_replicas ? 'Read Replicas' : nil}, the architecture gracefully handles #{@rps} RPS with P99 latency of #{p99_latency}ms and #{error_rate}% error rate."
      else
                      "System failed target requirements (Target: P99 < #{max_lat}ms, Error < #{max_err}% at #{number_with_delimiter(@challenge[:target_rps])} RPS). Current: P99 #{p99_latency}ms, #{error_rate}% errors."
      end

      Result.new(
        p99_latency_ms: p99_latency,
        error_rate_percent: error_rate,
        app_cpu_percent: app_cpu,
        db_connections_used: [ db_conns_used, 120 ].min,
        db_connection_limit: db_connection_limit,
        cache_hit_ratio_percent: (cache_hit_ratio * 100).round,
        queue_depth: has_queue ? [ (@rps / 500) * 12, 10 ].max : 0,
        monthly_cost: cost,
        bottlenecks: bottlenecks,
        verdict: verdict,
        passed: passed,
        explanation: explanation
      )
    end

    private

    def number_with_delimiter(num)
      num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end
end
