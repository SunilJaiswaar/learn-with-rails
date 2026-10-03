include SeedDSL
puts "  algorithm visualiser catalogue"

# Every slug here must have a tracer registered in Algorithms::Tracer.
records = [
  { slug: "linear-search", name: "Linear Search", category: "searching",
    skill: "searching", position: 1, visualizer_kind: "array",
    idea: "Check every element in order until you find the target.",
    pseudocode: "for each index i:\n  if array[i] == target: return i\nreturn nil",
    time_best: "O(1)", time_average: "O(n)", time_worst: "O(n)",
    space_complexity: "O(1)",
    tradeoffs: [ "Needs no precondition — works on unsorted data",
                 "Cannot beat O(n), so it is the baseline rather than the goal",
                 "Fine for small or one-off scans" ],
    production_note: "The right choice for a single lookup in unsorted data, " \
                     "where sorting first would cost more than the scan.",
    visualizer_config: { "input" => [ 8, 3, 7, 4, 2, 9, 1 ] } },

  { slug: "binary-search", name: "Binary Search", category: "searching",
    skill: "searching", position: 2, visualizer_kind: "array",
    idea: "Halve the search window each comparison. Requires sorted input.",
    pseudocode: "low, high = 0, n - 1\nwhile low <= high:\n  mid = (low + high) / 2\n  if a[mid] == target: return mid\n  if a[mid] < target: low = mid + 1\n  else: high = mid - 1",
    time_best: "O(1)", time_average: "O(log n)", time_worst: "O(log n)",
    space_complexity: "O(1)",
    tradeoffs: [ "Requires sorted, randomly-indexable input",
                 "20 comparisons for a million items",
                 "Sorting purely to enable it costs O(n log n)" ],
    production_note: "Database B-tree indexes are this idea on disk.",
    visualizer_config: { "input" => [ 1, 3, 5, 7, 9, 11, 13 ] } },

  { slug: "bubble-sort", name: "Bubble Sort", category: "sorting",
    skill: "sorting", position: 3, visualizer_kind: "array", stable: true,
    idea: "Repeatedly swap adjacent out-of-order pairs; the largest value " \
          "bubbles to the end each pass.",
    pseudocode: "for pass in 0...n:\n  swapped = false\n  for i in 0...(n - pass - 1):\n    if a[i] > a[i+1]: swap; swapped = true\n  break unless swapped",
    time_best: "O(n)", time_average: "O(n^2)", time_worst: "O(n^2)",
    space_complexity: "O(1)",
    tradeoffs: [ "O(n) on already-sorted input thanks to the early exit",
                 "O(n^2) everywhere else — never use it on real data",
                 "Worth learning because the swap animation makes sorting click" ],
    production_note: "Not used in production. It is a teaching algorithm.",
    visualizer_config: { "input" => [ 8, 3, 7, 4, 2 ] } },

  { slug: "insertion-sort", name: "Insertion Sort", category: "sorting",
    skill: "sorting", position: 4, visualizer_kind: "array", stable: true,
    idea: "Grow a sorted prefix by inserting each next element into place.",
    pseudocode: "for i in 1...n:\n  key = a[i]\n  j = i - 1\n  while j >= 0 and a[j] > key:\n    a[j+1] = a[j]; j -= 1\n  a[j+1] = key",
    time_best: "O(n)", time_average: "O(n^2)", time_worst: "O(n^2)",
    space_complexity: "O(1)",
    tradeoffs: [ "Excellent on small or nearly-sorted arrays",
                 "Stable and in-place",
                 "Real sort implementations fall back to it below ~16 elements" ],
    production_note: "Used inside production hybrid sorts (Timsort, introsort) " \
                     "for small partitions.",
    visualizer_config: { "input" => [ 8, 3, 7, 4, 2 ] } },

  { slug: "merge-sort", name: "Merge Sort", category: "sorting",
    skill: "sorting", position: 5, visualizer_kind: "array", stable: true,
    idea: "Split until single elements, then merge sorted halves back together.",
    pseudocode: "sort(lo, hi):\n  return if lo >= hi\n  mid = (lo + hi) / 2\n  sort(lo, mid); sort(mid+1, hi)\n  merge(lo, mid, hi)",
    time_best: "O(n log n)", time_average: "O(n log n)", time_worst: "O(n log n)",
    space_complexity: "O(n)",
    tradeoffs: [ "Guaranteed O(n log n) — no bad-input case",
                 "Stable, which matters when sorting by several keys in turn",
                 "Needs O(n) extra space, unlike quick sort" ],
    production_note: "The basis of external sorts for data larger than memory, " \
                     "because merging streams sequentially.",
    visualizer_config: { "input" => [ 8, 3, 7, 4, 2, 6 ] } },

  { slug: "quick-sort", name: "Quick Sort", category: "sorting",
    skill: "sorting", position: 6, visualizer_kind: "array", stable: false,
    idea: "Partition around a pivot so smaller values sit left, then recurse.",
    pseudocode: "sort(lo, hi):\n  return if lo >= hi\n  p = partition(lo, hi)\n  sort(lo, p-1); sort(p+1, hi)",
    time_best: "O(n log n)", time_average: "O(n log n)", time_worst: "O(n^2)",
    space_complexity: "O(log n)",
    tradeoffs: [ "Fastest in practice due to cache locality and in-place work",
                 "O(n^2) worst case on an adversarial or already-sorted input",
                 "Not stable, so equal elements can be reordered" ],
    production_note: "Most standard libraries use an introsort: quick sort that " \
                     "switches to heap sort when recursion gets too deep, which " \
                     "removes the O(n^2) case.",
    visualizer_config: { "input" => [ 8, 3, 7, 4, 2, 6 ] } },

  { slug: "two-pointer", name: "Two Pointers", category: "two_pointer",
    skill: "arrays-strings", position: 7, visualizer_kind: "array",
    idea: "Walk inward from both ends of a sorted array, moving whichever " \
          "pointer brings the sum toward the target.",
    pseudocode: "left, right = 0, n-1\nwhile left < right:\n  sum = a[left] + a[right]\n  return pair if sum == target\n  sum < target ? left += 1 : right -= 1",
    time_best: "O(1)", time_average: "O(n)", time_worst: "O(n)",
    space_complexity: "O(1)",
    tradeoffs: [ "O(1) space, unlike the hash approach",
                 "Requires sorted input",
                 "A hash is better when the data is unsorted and queried once" ],
    production_note: "Used when scanning large sorted datasets where keeping a " \
                     "hash of every value would not fit in memory.",
    visualizer_config: { "input" => [ 2, 3, 4, 7, 8, 11 ] } },

  { slug: "sliding-window", name: "Sliding Window", category: "sliding_window",
    skill: "arrays-strings", position: 8, visualizer_kind: "array",
    idea: "Maintain a running total over a fixed window, adding the entering " \
          "element and subtracting the leaving one.",
    pseudocode: "sum = sum of first k\nfor i in k...n:\n  sum += a[i] - a[i-k]\n  best = max(best, sum)",
    time_best: "O(n)", time_average: "O(n)", time_worst: "O(n)",
    space_complexity: "O(1)",
    tradeoffs: [ "Turns the naive O(n*k) recomputation into O(n)",
                 "Only works when the measure can be updated incrementally",
                 "Variable-size windows need a different loop shape" ],
    production_note: "How rate limiters and moving-average metrics are computed.",
    visualizer_config: { "input" => [ 4, 2, 9, 7, 1, 8, 3 ], "window" => 3 } },

  { slug: "breadth-first-search", name: "Breadth-First Search", category: "graph",
    skill: "algorithmic-thinking", position: 9, visualizer_kind: "graph",
    idea: "Explore level by level using a queue, so the first time you reach a " \
          "node you have reached it by the fewest edges.",
    pseudocode: "queue = [start]\nuntil queue.empty?:\n  node = queue.shift\n  visit(node)\n  queue.concat(unvisited neighbours)",
    time_best: "O(V + E)", time_average: "O(V + E)", time_worst: "O(V + E)",
    space_complexity: "O(V)",
    tradeoffs: [ "Finds shortest paths in unweighted graphs",
                 "Memory grows with the width of the graph",
                 "Needs Dijkstra once edges have weights" ],
    production_note: "Degrees of separation, shortest route on an unweighted map, " \
                     "crawling a site breadth-first." },

  { slug: "depth-first-search", name: "Depth-First Search", category: "graph",
    skill: "algorithmic-thinking", position: 10, visualizer_kind: "graph",
    idea: "Follow one branch to its end before backtracking, using a stack.",
    pseudocode: "stack = [start]\nuntil stack.empty?:\n  node = stack.pop\n  visit(node)\n  stack.concat(unvisited neighbours)",
    time_best: "O(V + E)", time_average: "O(V + E)", time_worst: "O(V + E)",
    space_complexity: "O(V)",
    tradeoffs: [ "Memory grows with depth, not width",
                 "Does not give shortest paths",
                 "Natural fit for cycle detection and topological sort" ],
    production_note: "Dependency resolution and cycle detection in build tools." },

  { slug: "fibonacci-memoisation", name: "Memoisation (Fibonacci)",
    category: "dynamic_programming", skill: "complexity", position: 11,
    visualizer_kind: "dp_table",
    idea: "Store each solved subproblem so the exponential recursion tree " \
          "collapses into a linear table.",
    pseudocode: "table[0], table[1] = 0, 1\nfor i in 2..n:\n  table[i] = table[i-1] + table[i-2]",
    time_best: "O(n)", time_average: "O(n)", time_worst: "O(n)",
    space_complexity: "O(n), or O(1) keeping only the last two",
    tradeoffs: [ "Turns O(2^n) into O(n)",
                 "Costs memory proportional to the state space",
                 "Only valid when subproblems genuinely overlap" ],
    production_note: "The same idea as caching an expensive pure function." }
]

records.each do |attrs|
  skill_slug = attrs.delete(:skill)
  Algorithm.find_or_create_by!(slug: attrs[:slug]) do |a|
    a.assign_attributes(attrs)
    a.skill = skill!(skill_slug)
  end
end

# Fail loudly if a catalogue entry has no tracer: a visualiser page with no
# trace is exactly the "empty page" the spec forbids.
missing = Algorithm.pluck(:slug).reject { |slug| Algorithms::Tracer.supports?(slug) }
raise "Algorithms without tracers: #{missing.join(', ')}" if missing.any?
