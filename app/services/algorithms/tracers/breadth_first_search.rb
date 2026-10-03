module Algorithms
  module Tracers
    # Graph traversal. The visualiser shows the queue as it changes, which is
    # the part that makes BFS click (spec 7).
    class BreadthFirstSearch < Base
      DEFAULT_GRAPH = {
        "A" => %w[B C],
        "B" => %w[D E],
        "C" => %w[F],
        "D" => [],
        "E" => %w[F],
        "F" => []
      }.freeze

      def self.visualizer_kind
        "graph"
      end

      def initialize(graph: nil, start: nil)
        @graph = graph || DEFAULT_GRAPH
        @start = start
      end

      # Graph tracers ignore the array input and walk their own adjacency list.
      def call(_input = nil)
        @frames = []
        @comparisons = 0
        @swaps = 0
        trace(nil)
        frames
      end

      private

      def trace(_input)
        graph = @graph.transform_keys(&:to_s)
        start = @start || graph.keys.first
        visited = []
        queue = [ start ]
        order = []

        emit("Start at #{start}. BFS uses a queue, so nodes leave in the order they arrived.",
             data: graph_payload(graph),
             markers: { current: start, visited: [], frontier: queue.dup },
             aux: { "label" => "Queue", "items" => queue.dup })

        until queue.empty?
          node = queue.shift
          next if visited.include?(node)

          visited << node
          order << node
          count_comparison!

          emit("Dequeue #{node} and mark it visited.",
               data: graph_payload(graph),
               markers: { current: node, visited: visited.dup, frontier: queue.dup },
               aux: { "label" => "Queue", "items" => queue.dup })

          neighbours = graph.fetch(node, []).reject do |n|
            visited.include?(n) || queue.include?(n)
          end
          next if neighbours.empty?

          queue.concat(neighbours)
          emit("Enqueue #{node}'s unvisited neighbours: #{neighbours.join(', ')}.",
               data: graph_payload(graph),
               markers: { current: node, visited: visited.dup, frontier: queue.dup,
                          discovered: neighbours },
               aux: { "label" => "Queue", "items" => queue.dup })
        end

        emit("Queue is empty. Visit order: #{order.join(' -> ')}. " \
             "BFS explores level by level, so it finds the shortest unweighted path.",
             data: graph_payload(graph),
             markers: { visited: visited.dup },
             aux: { "label" => "Visit order", "items" => order })
      end

      def graph_payload(graph)
        {
          "nodes" => graph.keys,
          "edges" => graph.flat_map { |from, tos| tos.map { |to| [ from, to ] } }
        }
      end
    end
  end
end
