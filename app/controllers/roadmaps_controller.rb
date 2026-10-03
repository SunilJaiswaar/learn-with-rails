# Roadmaps (spec 66): an ordered route through the skill graph.
#
# LearningPath held three records and had no route, so the entire roadmap
# concept — the brief's ROLE → ROADMAP layer — was unreachable (audit B2).
class RoadmapsController < ApplicationController
  def index
    builder = Skills::TreeBuilder.new(user: current_user)

    @roadmaps = LearningPath.published.ordered.includes(learning_path_steps: :skill)
    @rollups = @roadmaps.index_with do |roadmap|
      Skills::Rollup.new(builder.nodes_for_skill_ids(roadmap.learning_path_steps.map(&:skill_id)))
    end
  end

  def show
    @roadmap = LearningPath.published.find_by_slug!(params[:id])
    builder = Skills::TreeBuilder.new(user: current_user)

    @steps = @roadmap.learning_path_steps.ordered.includes(:skill)
    node_index = builder.nodes.index_by { |node| node.skill.id }
    # Each step carries its own note, so the step and its tree node travel
    # together rather than the view reaching back into the builder.
    @rows = @steps.map { |step| [ step, node_index[step.skill_id] ] }
    @rollup = Skills::Rollup.new(@rows.map(&:last).compact)
  end
end
