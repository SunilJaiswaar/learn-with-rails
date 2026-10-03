module Algorithms
  module Tracers
    # Dijkstra's shortest path algorithm.
    # Shows: Node, Distance, Visited, and Priority Queue (spec 7).
    class Dijkstra < Base
      DEFAULT_GRAPH = {
        "A" => [ [ "B", 4 ], [ "C", 2 ] ],
        "B" => [ [ "C", 1 ], [ "D", 5 ] ],
        "C" => [ [ "D", 8 ], [ "E", 10 ] ],
        "D" => [ [ "E", 2 ], [ "F", 6 ] ],
        "E" => [ [ "F", 3 ] ],
        "F" => []
      }.freeze

      def self.visualizer_kind
        "graph"
      end

      def initialize(graph: nil, start: nil)
        @graph = graph || DEFAULT_GRAPH
        @start = start
      end

      def call(_input = nil)
        @frames = []
        @comparisons = 0
        @swaps = 0
        trace
        frames
      end

      private

      def trace
        graph = @graph.transform_keys(&:to_s)
        nodes = (graph.keys + graph.values.flat_map { |edges| edges.map(&:first) }).uniq
        start = @start || nodes.first

        distances = nodes.each_with_object({}) { |n, h| h[n] = Float::INFINITY }
        distances[start] = 0
        visited = []
        pq = [ [ 0, start ] ]

        emit("Initialize Dijkstra: Distance to start (#{start}) is 0, all others ∞. Priority Queue holds [#{start}: 0].",
             data: graph_payload(graph, nodes),
             markers: { current: start, visited: [], frontier: [ start ] },
             aux: { "label" => "Priority Queue", "items" => [ "#{start}: 0" ] })

        until pq.empty?
          pq.sort_by!(&:first)
          dist, current = pq.shift

          next if visited.include?(current)

          visited << current
          count_comparison!

          emit("Extract min from PQ: Node #{current} with shortest confirmed distance #{dist}.",
               data: graph_payload(graph, nodes),
               markers: { current: current, visited: visited.dup, frontier: pq.map(&:last) },
               aux: { "label" => "Priority Queue", "items" => pq_items(pq, distances) })

          edges = graph.fetch(current, [])
          edges.each do |neighbor, weight|
            count_comparison!
            next if visited.include?(neighbor)

            new_dist = dist + weight
            if new_dist < distances[neighbor]
              old_val = distances[neighbor] == Float::INFINITY ? "∞" : distances[neighbor]
              distances[neighbor] = new_dist
              pq << [ new_dist, neighbor ]
              pq.sort_by!(&:first)

              emit("Relax edge #{current} → #{neighbor} (weight #{weight}): new distance #{new_dist} < #{old_val}. Update PQ.",
                   data: graph_payload(graph, nodes),
                   markers: { current: current, visited: visited.dup, frontier: pq.map(&:last),
                              discovered: [ neighbor ] },
                   aux: { "label" => "Priority Queue", "items" => pq_items(pq, distances) })
            end
          end
        end

        summary_items = nodes.map { |n| "#{n}: #{distances[n] == Float::INFINITY ? '∞' : distances[n]}" }
        emit("Dijkstra complete. All reachable shortest paths from #{start} resolved: #{summary_items.join(', ')}.",
             data: graph_payload(graph, nodes),
             markers: { visited: visited.dup },
             aux: { "label" => "Shortest Distances", "items" => summary_items })
      end

      def pq_items(pq, _distances)
        return [ "empty" ] if pq.empty?

        pq.map { |d, n| "#{n} (dist: #{d})" }
      end

      def graph_payload(graph, nodes)
        edges = []
        graph.each do |from, neighbors|
          neighbors.each do |to, weight|
            edges << [ "#{from}(#{weight})", to ]
          end
        end

        {
          "nodes" => nodes,
          "edges" => edges
        }
      end
    end
  end
end
