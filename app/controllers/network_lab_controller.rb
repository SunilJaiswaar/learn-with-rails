class NetworkLabController < ApplicationController
  before_action :require_authentication

  LAYERS = {
    "browser" => {
      name: "1. Web Browser (Client)",
      icon: "🌐",
      protocol: "User Agent",
      summary: "Generates the HTTP request, parses HTML, resolves DNS from cache, manages cookies, and renders DOM.",
      headers: {
        "Request": "GET /api/v1/orders HTTP/2",
        "Host": "api.codequest.dev",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
        "Accept": "application/json, text/html",
        "Accept-Encoding": "gzip, deflate, br",
        "Cookie": "_codequest_session=9a7b...; theme=dark",
        "Sec-Fetch-Site": "same-origin"
      },
      telemetry: "Client Time: 0ms · Socket State: NEW · DNS Cache: MISS",
      explanation: "The browser checks its own local DNS cache (typically 60s TTL), then OS resolver cache. If missing, it kicks off a recursive DNS lookup."
    },
    "dns" => {
      name: "2. DNS Resolution (Route 53)",
      icon: "🧭",
      protocol: "DNS (UDP/53)",
      summary: "Translates human-readable domain name (api.codequest.dev) into a routable IP address (198.51.100.42).",
      headers: {
        "Transaction ID": "0x4a12",
        "Flags": "0x0100 (Standard query)",
        "Questions": "1",
        "Query": "api.codequest.dev (Type A, Class IN)",
        "Answer": "198.51.100.42 (TTL 300s)",
        "Authoritative": "ns1.codequest-dns.com"
      },
      telemetry: "DNS Query Latency: 14ms · Protocol: UDP · Port: 53",
      explanation: "Without DNS, computers could only communicate via raw numeric IP addresses. DNS acts as the decentralized telephone directory of the Internet."
    },
    "ip" => {
      name: "3. IP Layer (Network Routing)",
      icon: "🗺️",
      protocol: "IPv4 / IPv6",
      summary: "Handles host-to-host packet addressing and routing across intermediate routers and Internet Exchanges (BGP).",
      headers: {
        "Version": "4",
        "Header Length": "20 bytes",
        "Total Length": "1,500 bytes (MTU limit)",
        "TTL (Time to Live)": "64 hops",
        "Protocol": "6 (TCP)",
        "Source IP": "192.0.2.15 (Client)",
        "Destination IP": "198.51.100.42 (Load Balancer)"
      },
      telemetry: "Packet Size: 1,500 B · Route Hops: 9 hops · MTU: 1,500",
      explanation: "IP is connectionless and best-effort; it does not guarantee packets will arrive in order or arrive at all. TCP builds reliability on top of IP."
    },
    "tcp" => {
      name: "4. TCP Handshake (Transport)",
      icon: "🤝",
      protocol: "TCP (Port 443)",
      summary: "Establishes a reliable, ordered, bi-directional byte stream using a 3-Way Handshake (SYN → SYN-ACK → ACK).",
      headers: {
        "Source Port": "54210 (Ephemeral)",
        "Destination Port": "443 (HTTPS)",
        "Sequence Number": "2,401,984",
        "Acknowledgment Number": "3,119,002",
        "Flags": "[ACK, PSH] Window Size: 65,535 bytes",
        "Congestion Window (cwnd)": "10 MSS",
        "State": "ESTABLISHED"
      },
      telemetry: "3-Way Handshake: 28ms (1 RTT) · Retransmissions: 0 · Window: 64KB",
      explanation: "TCP guarantees delivery via sequence numbers and ACKs. If a packet is lost in transit, TCP detects the gap and retransmits it automatically."
    },
    "tls" => {
      name: "5. TLS 1.3 Handshake (Cryptographic Security)",
      icon: "🔒",
      protocol: "TLS 1.3",
      summary: "Authenticates the server's certificate and negotiates ephemeral symmetric encryption keys (ECDHE).",
      headers: {
        "Version": "TLS 1.3 (0x0304)",
        "Cipher Suite": "TLS_AES_256_GCM_SHA384",
        "Key Exchange": "X25519 (Diffie-Hellman)",
        "Server Certificate": "CN=api.codequest.dev (Issued by Let's Encrypt, Valid)",
        "Handshake Latency": "1 RTT (0-RTT resumption available)"
      },
      telemetry: "Encryption: AES-256-GCM (Authenticated Encryption) · Forward Secrecy: YES",
      explanation: "TLS guarantees Confidentiality (eavesdroppers see only ciphertext), Integrity (tampering invalidates HMAC), and Authentication (proves server identity)."
    },
    "http" => {
      name: "6. HTTP/2 Framing (Application Protocol)",
      icon: "📄",
      protocol: "HTTP/2",
      summary: "Multiplexes requests over a single TCP connection into binary frames with header compression (HPACK).",
      headers: {
        ":method": "GET",
        ":path": "/api/v1/orders",
        ":scheme": "https",
        ":authority": "api.codequest.dev",
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-cache, private",
        "status": "200 OK"
      },
      telemetry: "Stream ID: 1 · Framing: Binary DATA · HPACK Savings: 68%",
      explanation: "HTTP/2 eliminates Head-of-Line blocking in the browser by streaming multiple simultaneous requests over a single TLS connection."
    },
    "load_balancer" => {
      name: "7. Load Balancer (Reverse Proxy)",
      icon: "⚖️",
      protocol: "AWS ALB / Nginx",
      summary: "Terminates TLS, performs health checks, adds X-Forwarded-For headers, and balances requests across app servers.",
      headers: {
        "X-Forwarded-For": "192.0.2.15",
        "X-Forwarded-Proto": "https",
        "X-Forwarded-Port": "443",
        "Target Group": "rails-web-cluster-tg (Healthy: 6/6)",
        "Algorithm": "Least Outstanding Requests (Round-Robin fallback)"
      },
      telemetry: "Routing Delay: 0.8ms · Active Targets: 6 nodes · TLS Offload: YES",
      explanation: "The Load Balancer terminates client TLS at the edge and forwards plain HTTP over high-speed private VPC interfaces to application instances."
    },
    "app_server" => {
      name: "8. Rails App Server (Puma)",
      icon: "💎",
      protocol: "Rack / Ruby 3.4",
      summary: "Executes application logic, checks session token, verifies authorization, and queries the database.",
      headers: {
        "Server": "Puma 6.4 (clustered mode)",
        "Rack-Version": "3.0",
        "Controller": "Api::V1::OrdersController#index",
        "Session User": "User #1402 (learner@example.com)",
        "DB Query Duration": "4.2ms"
      },
      telemetry: "Worker #2 (Thread #4) · Allocation: 2.1 MB · GC Cycles: 0",
      explanation: "Puma executes the Rack call method, passing the request environment hash down the middleware stack to the Rails router and controller."
    },
    "database" => {
      name: "9. PostgreSQL Database",
      icon: "🐘",
      protocol: "PostgreSQL Wire Protocol (5432)",
      summary: "Parses, plans, and executes relational SQL query using indexes, returning rows to the application server.",
      headers: {
        "Query": "SELECT orders.* FROM orders WHERE orders.user_id = 1402 ORDER BY created_at DESC LIMIT 20;",
        "Execution Plan": "Index Scan using index_orders_on_user_id (cost=0.29..8.31 rows=20 width=142)",
        "Buffer Hits": "12 shared hit blocks (0 disk read)",
        "Execution Time": "0.420 ms"
      },
      telemetry: "Index Used: YES (B-Tree) · Rows Returned: 20 · Connection: Pooled",
      explanation: "The query planner uses the B-tree index on user_id to jump directly to the target leaf nodes in memory without a costly sequential disk scan."
    }
  }.freeze

  def show
    @active_layer = params[:layer].presence || "browser"
    @layer_data = LAYERS[@active_layer] || LAYERS["browser"]
    @challenge = params[:challenge]
  end

  def inspect_layer
    @active_layer = params[:layer].presence || "browser"
    @layer_data = LAYERS[@active_layer] || LAYERS["browser"]

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to network_lab_path(layer: @active_layer) }
    end
  end

  def solve_challenge
    challenge_id = params[:challenge_id]
    correct = case challenge_id
    when "https_security"
                params[:answer] == "encryption_authentication"
    when "dns_need"
                params[:answer] == "name_to_ip"
    when "tcp_timeout"
                params[:answer] == "syn_unanswered"
    else
                false
    end

    if correct
      Gamification::XpAward.new(
        user: current_user,
        amount: 150,
        reason: "Solved Networking Lab Challenge: #{challenge_id.titleize}",
        idempotency_key: "net-challenge-#{challenge_id}-#{current_user.id}"
      ).call

      flash[:notice] = "Correct! You understand the foundational networking protocols (+150 XP)."
    else
      flash[:alert] = "Not quite. Inspect the headers and protocol telemetry, then try again."
    end

    redirect_to network_lab_path(layer: params[:layer] || "browser")
  end
end
