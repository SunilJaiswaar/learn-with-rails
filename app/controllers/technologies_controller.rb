# The technology registry (spec 74): version-aware, learner-facing.
#
# Technology and TechnologyVersion were reachable only through
# /admin/technology_versions, so a learner could not see which version of a
# language the curriculum teaches or which are legacy (audit B5).
class TechnologiesController < ApplicationController
  def index
    builder = Skills::TreeBuilder.new(user: current_user)

    @technologies = Technology.ordered.includes(:technology_versions, :skills)
    @rollups = @technologies.index_with do |technology|
      Skills::Rollup.new(builder.nodes_for_technology(technology))
    end
  end

  def show
    @technology = Technology.find_by_slug!(params[:id])
    builder = Skills::TreeBuilder.new(user: current_user)

    @nodes = builder.nodes_for_technology(@technology)
    @rollup = Skills::Rollup.new(@nodes)
    @versions = @technology.technology_versions.newest_first
    @current_version = @technology.current_version
  end
end
