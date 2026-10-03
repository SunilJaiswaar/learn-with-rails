# The skill tree (spec 50): an interconnected graph, not a list.
class SkillMapController < ApplicationController
  def show
    builder = Skills::TreeBuilder.new(user: current_user)
    @nodes_by_world = builder.nodes_by_world
    @edges = builder.edges
    @node_index = builder.nodes.index_by { |node| node.skill.id }
    @next_topic = builder.next_topic
  end
end
