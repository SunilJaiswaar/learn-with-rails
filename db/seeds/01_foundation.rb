# Settings, technologies and version metadata (spec 60).
puts "  settings, technologies, versions"

AppSetting::DEFAULTS.each do |key, payload|
  AppSetting.find_or_create_by!(key: key) do |setting|
    setting.value = payload
    setting.category = "branding"
    setting.description = "Editable from the admin settings screen."
  end
end

technologies = [
  { name: "Ruby", slug: "ruby", category: "language", icon: "◆", position: 1,
    summary: "A dynamic, object-oriented language where almost everything is an object.",
    versions: [
      { number: "3.4", status: :current, released_on: Date.new(2024, 12, 25),
        docs_url: "https://docs.ruby-lang.org/en/3.4/" },
      { number: "3.1", status: :maintained, released_on: Date.new(2021, 12, 25),
        docs_url: "https://docs.ruby-lang.org/en/3.1/" },
      { number: "2.7", status: :eol, released_on: Date.new(2019, 12, 25),
        deprecated_on: Date.new(2023, 3, 31),
        notes: "Kept for interview preparation only. Do not teach as current." }
    ] },
  { name: "PostgreSQL", slug: "postgresql", category: "database", icon: "▣", position: 2,
    summary: "A relational database with a sophisticated query planner.",
    versions: [
      { number: "17", status: :current, released_on: Date.new(2024, 9, 26),
        docs_url: "https://www.postgresql.org/docs/17/" },
      { number: "14", status: :maintained, released_on: Date.new(2021, 9, 30) },
      { number: "11", status: :eol, released_on: Date.new(2018, 10, 18),
        deprecated_on: Date.new(2023, 11, 9) }
    ] },
  { name: "SQL", slug: "sql", category: "language", icon: "⌗", position: 3,
    summary: "The declarative language for querying relational data.",
    versions: [ { number: "SQL:2016", status: :current } ] }
]

technologies.each do |attrs|
  versions = attrs.delete(:versions)
  technology = Technology.find_or_create_by!(slug: attrs[:slug]) do |t|
    t.assign_attributes(attrs)
  end
  versions.each do |version_attrs|
    TechnologyVersion.find_or_create_by!(technology: technology,
                                         number: version_attrs[:number]) do |v|
      v.assign_attributes(version_attrs)
    end
  end
end

puts "  worlds"
worlds = [
  { name: "Programming Forest", slug: "programming-forest", position: 1,
    accent_color: "#34d399", icon: "🌲",
    tagline: "Where code stops being magic.",
    summary: "Variables, control flow, collections and the errors that teach you most." },
  { name: "Algorithm Arena", slug: "algorithm-arena", position: 2,
    accent_color: "#f59e0b", icon: "⚔",
    tagline: "Watch algorithms run, step by step.",
    summary: "Searching, sorting, traversal and the cost of every choice." },
  { name: "Database Dungeon", slug: "database-dungeon", position: 3,
    accent_color: "#60a5fa", icon: "🗄",
    tagline: "Every query has a plan. Learn to read it.",
    summary: "SQL from SELECT to window functions, then indexes and query plans." },
  { name: "Ruby Kingdom", slug: "ruby-kingdom", position: 4,
    accent_color: "#f87171", icon: "💎",
    tagline: "Blocks, objects and the method lookup path.",
    summary: "Ruby from literals to blocks, modules and metaprogramming." },
  { name: "Computer City", slug: "computer-city", position: 5,
    accent_color: "#a78bfa", icon: "🏙",
    tagline: "What the machine is actually doing.",
    summary: "Binary, memory, processes and why any of it affects your code." }
]
worlds.each { |attrs| World.find_or_create_by!(slug: attrs[:slug]) { |w| w.assign_attributes(attrs) } }
