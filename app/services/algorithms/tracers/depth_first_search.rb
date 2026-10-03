module Algorithms
  module Tracers
    # DFS shows the call stack, which is what distinguishes it from BFS.
    class DepthFirstSearch < BreadthFirstSearch
      private

      def trace(_input)
        graph = @graph.transform_keys(&:to_s)
        start = @start || graph.keys.first
        visited = []
        order = []
        stack = [ start ]

        emit("Start at #{start}. DFS uses a stack, so the most recently " \
             "discovered node is explored first.",
             data: graph_payload(graph),
             markers: { current: start, visited: [], frontier: stack.dup },
             aux: { "label" => "Stack", "items" => stack.dup })

        until stack.empty?
          node = stack.pop
          next if visited.include?(node)

          visited << node
          order << node
          count_comparison!

          emit("Pop #{node} and mark it visited.",
               data: graph_payload(graph),
               markers: { current: node, visited: visited.dup, frontier: stack.dup },
               aux: { "label" => "Stack", "items" => stack.dup })

          neighbours = graph.fetch(node, []).reject { |n| visited.include?(n) }
          next if neighbours.empty?

          # Reversed so the first neighbour is explored first.
          stack.concat(neighbours.reverse)
          emit("Push #{node}'s unvisited neighbours. #{neighbours.first} goes deeper next.",
               data: graph_payload(graph),
               markers: { current: node, visited: visited.dup, frontier: stack.dup,
                          discovered: neighbours },
               aux: { "label" => "Stack", "items" => stack.dup })
        end

        emit("Stack is empty. Visit order: #{order.join(' -> ')}. " \
             "DFS dives to the bottom of one branch before backtracking.",
             data: graph_payload(graph),
             markers: { visited: visited.dup },
             aux: { "label" => "Visit order", "items" => order })
      end
    end
  end
end
