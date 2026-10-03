# The skill tree (spec 50). Slugs are stable identifiers referenced by the
# mastery report, quest templates and interview templates.
puts "  skills and prerequisites"

forest   = World.find_by!(slug: "programming-forest")
arena    = World.find_by!(slug: "algorithm-arena")
dungeon  = World.find_by!(slug: "database-dungeon")
kingdom  = World.find_by!(slug: "ruby-kingdom")
city     = World.find_by!(slug: "computer-city")

ruby_tech = Technology.find_by!(slug: "ruby")
sql_tech  = Technology.find_by!(slug: "sql")
pg_tech   = Technology.find_by!(slug: "postgresql")

skills = [
  # --- Programming / Ruby ------------------------------------------------
  { slug: "ruby-basics", name: "Ruby Basics", world: forest, technology: ruby_tech,
    tier: 0, position: 1, grid_x: 0, grid_y: 0,
    summary: "Variables, types, truthiness and the errors you will see most." },
  { slug: "ruby-collections", name: "Arrays & Hashes", world: forest, technology: ruby_tech,
    tier: 1, position: 1, grid_x: 0, grid_y: 1,
    summary: "The two data structures that carry most Ruby programs." },
  { slug: "ruby-blocks", name: "Blocks & Enumerable", world: kingdom, technology: ruby_tech,
    tier: 2, position: 1, grid_x: 0, grid_y: 2,
    summary: "yield, procs, lambdas and why map beats each with <<." },
  { slug: "debugging-skill", name: "Debugging", world: forest, technology: ruby_tech,
    tier: 1, position: 2, grid_x: 1, grid_y: 1,
    summary: "Reading a stack trace, forming a hypothesis, proving it." },

  # --- Algorithms --------------------------------------------------------
  { slug: "algorithmic-thinking", name: "Algorithmic Thinking", world: arena,
    tier: 1, position: 1, grid_x: 2, grid_y: 1,
    summary: "Turning a vague problem into steps you can count." },
  { slug: "complexity", name: "Big-O & Complexity", world: arena,
    tier: 2, position: 1, grid_x: 2, grid_y: 2,
    summary: "Why 1,000,000 records changes which solution is allowed." },
  { slug: "searching", name: "Searching", world: arena,
    tier: 2, position: 2, grid_x: 3, grid_y: 2,
    summary: "Linear vs binary search, and the precondition that makes it work." },
  { slug: "sorting", name: "Sorting", world: arena,
    tier: 3, position: 1, grid_x: 2, grid_y: 3,
    summary: "Bubble, insertion, merge and quick sort, watched step by step." },
  { slug: "arrays-strings", name: "Arrays & Strings", world: arena,
    tier: 2, position: 3, grid_x: 4, grid_y: 2,
    summary: "Two pointers, sliding windows and prefix sums." },
  { slug: "hash-maps", name: "Hash Maps", world: arena,
    tier: 3, position: 2, grid_x: 4, grid_y: 3,
    summary: "Trading memory for time, and when a Set is the right answer." },

  # --- SQL / databases ---------------------------------------------------
  { slug: "sql-basics", name: "SQL Basics", world: dungeon, technology: sql_tech,
    tier: 0, position: 2, grid_x: 6, grid_y: 0,
    summary: "SELECT, WHERE, ORDER BY and the shape of a result set." },
  { slug: "sql-joins", name: "SQL Joins", world: dungeon, technology: sql_tech,
    tier: 1, position: 3, grid_x: 6, grid_y: 1,
    summary: "INNER, LEFT, the NULLs that appear and the duplicates that surprise you." },
  { slug: "sql-aggregation", name: "Aggregation & Grouping", world: dungeon,
    technology: sql_tech, tier: 2, position: 4, grid_x: 6, grid_y: 2,
    summary: "GROUP BY, HAVING, and why COUNT(*) and COUNT(col) differ." },
  { slug: "indexing", name: "Indexes", world: dungeon, technology: pg_tech,
    tier: 3, position: 3, grid_x: 7, grid_y: 3,
    summary: "B-trees, selectivity and the index the planner ignores." },
  { slug: "query-performance", name: "Query Performance", world: dungeon,
    technology: pg_tech, tier: 4, position: 1, grid_x: 6, grid_y: 4,
    summary: "Reading EXPLAIN ANALYZE and fixing the slow query, not the symptom." },

  # --- Machine -----------------------------------------------------------
  { slug: "number-systems", name: "Binary & Hex", world: city,
    tier: 0, position: 3, grid_x: 9, grid_y: 0,
    summary: "Why computers count in twos, and where hex comes from." },
  { slug: "memory-model", name: "Memory & References", world: city,
    tier: 1, position: 4, grid_x: 9, grid_y: 1,
    summary: "Stack, heap, and the aliasing bug that bites every beginner." }
]

skills.each do |attrs|
  Skill.find_or_create_by!(slug: attrs[:slug]) { |s| s.assign_attributes(attrs) }
end

# Prerequisite edges: skill <- prerequisite.
edges = {
  "ruby-collections" => %w[ruby-basics],
  "ruby-blocks" => %w[ruby-collections],
  "debugging-skill" => %w[ruby-basics],
  "algorithmic-thinking" => %w[ruby-basics],
  "complexity" => %w[algorithmic-thinking],
  "searching" => %w[algorithmic-thinking ruby-collections],
  "sorting" => %w[searching complexity],
  "arrays-strings" => %w[ruby-collections algorithmic-thinking],
  "hash-maps" => %w[arrays-strings complexity],
  "sql-joins" => %w[sql-basics],
  "sql-aggregation" => %w[sql-joins],
  "indexing" => %w[sql-aggregation complexity],
  "query-performance" => %w[indexing],
  "memory-model" => %w[number-systems ruby-basics]
}

edges.each do |skill_slug, prerequisite_slugs|
  skill = Skill.find_by!(slug: skill_slug)
  prerequisite_slugs.each do |prerequisite_slug|
    SkillDependency.find_or_create_by!(
      skill: skill, prerequisite: Skill.find_by!(slug: prerequisite_slug)
    )
  end
end

puts "  learning paths"
paths = [
  { slug: "ruby-on-rails-developer", name: "Ruby on Rails Developer", position: 1,
    audience: "Aiming at a Rails role",
    summary: "Language fundamentals, then data, then the framework.",
    skills: %w[ruby-basics ruby-collections ruby-blocks debugging-skill
               sql-basics sql-joins sql-aggregation indexing query-performance] },
  { slug: "interview-fast-track", name: "Interview Fast Track", position: 2,
    audience: "Interviewing in the next few weeks",
    summary: "The topics that come up in almost every technical screen.",
    skills: %w[algorithmic-thinking complexity searching sorting arrays-strings
               hash-maps sql-joins sql-aggregation] },
  { slug: "absolute-beginner", name: "Absolute Beginner", position: 0,
    audience: "Never programmed before",
    summary: "Start from what a variable is and end able to solve problems.",
    skills: %w[number-systems ruby-basics ruby-collections debugging-skill
               memory-model algorithmic-thinking] }
]

paths.each do |attrs|
  skill_slugs = attrs.delete(:skills)
  path = LearningPath.find_or_create_by!(slug: attrs[:slug]) { |p| p.assign_attributes(attrs) }
  skill_slugs.each_with_index do |slug, index|
    LearningPathStep.find_or_create_by!(learning_path: path,
                                        skill: Skill.find_by!(slug: slug)) do |step|
      step.position = index
    end
  end
end
