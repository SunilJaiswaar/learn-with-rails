module Labs
  # The interactive laboratories, and which skill each one is evidence for.
  #
  # Without this mapping the labs are orphaned: reachable from the dashboard
  # but contributing nothing to the skill tree or to measured mastery, so a
  # learner can spend an hour in the Redis Vault and their Redis skill stays at
  # zero. The registry is what connects them.
  module Catalogue
    # `dimension` is the mastery dimension a lab proves. Labs are hands-on
    # application rather than recall, so most prove :application; the ones that
    # are primarily about reading evidence prove :debugging.
    LABS = {
      "system_design" => {
        name: "System Design Simulator", icon: "🌐", skill: "architecture",
        route: :system_design_index_path, dimension: :application,
        summary: "Design under production traffic, then inject failures."
      },
      "network_lab" => {
        name: "Networking Lab", icon: "🧭", skill: "distributed-systems",
        route: :network_lab_path, dimension: :application,
        summary: "DNS, the TCP handshake, TLS and packet inspection."
      },
      "redis_vault" => {
        name: "Redis Vault", icon: "🧠", skill: "redis-caching",
        route: :redis_vault_path, dimension: :application,
        summary: "In-memory structures, TTL and a token-bucket limiter."
      },
      "sidekiq_factory" => {
        name: "Sidekiq Factory", icon: "⚙", skill: "background-jobs",
        route: :sidekiq_factory_path, dimension: :application,
        summary: "Queues, concurrency, retries and the dead set."
      },
      "git_lab" => {
        name: "Git Time Machine", icon: "🕰", skill: "git-fundamentals",
        route: :git_lab_path, dimension: :application,
        summary: "Run commands against a commit graph and watch it move."
      },
      "cicd_game" => {
        name: "CI/CD Pipeline Repair", icon: "🔧", skill: "ci-cd",
        route: :cicd_game_path, dimension: :debugging,
        summary: "Read the build log, find why the gate failed, fix it."
      },
      "security_lab" => {
        name: "Security Fortress", icon: "🛡", skill: "web-security",
        route: :security_lab_path, dimension: :application,
        summary: "Run an exploit against vulnerable and secured code."
      },
      "cpu_scheduler" => {
        name: "CPU Scheduler", icon: "⏱", skill: "concurrency",
        route: :cpu_scheduler_path, dimension: :application,
        summary: "Schedule processes and watch the waiting time change."
      },
      "hotwire_lab" => {
        name: "Hotwire Lab", icon: "⚡", skill: "dom-rendering",
        route: :hotwire_lab_path, dimension: :prediction,
        summary: "Turbo frames and streams against a live DOM."
      },
      "incidents" => {
        name: "Production Incidents", icon: "🚨", skill: "observability",
        route: :incidents_path, dimension: :debugging,
        summary: "Diagnose real failures from logs, metrics and traces."
      }
    }.freeze

    # The championship is deliberately absent: it is a capstone across every
    # skill, so attributing it to one would misreport mastery.

    class << self
      def all
        LABS
      end

      def find(key)
        LABS[key.to_s]
      end

      def for_skill(skill_slug)
        LABS.select { |_key, lab| lab[:skill] == skill_slug }
      end

      def skill_for(key)
        lab = find(key)
        return nil if lab.nil?

        Skill.find_by(slug: lab[:skill])
      end

      # Fails loudly if a lab points at a skill that does not exist, so a
      # renamed skill cannot silently orphan a lab again.
      def missing_skills
        LABS.values.map { |lab| lab[:skill] }.uniq -
          Skill.where(slug: LABS.values.map { |lab| lab[:skill] }).pluck(:slug)
      end
    end
  end
end
