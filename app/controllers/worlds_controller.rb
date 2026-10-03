# The world map (spec 6, 100): the brief's primary LEARN entry.
#
# World had nine records and no route at all before this — the organising
# metaphor of the whole platform existed in the database and not in the
# product (audit U1, B1).
class WorldsController < ApplicationController
  def index
    builder = Skills::TreeBuilder.new(user: current_user)

    @worlds = World.published.ordered.to_a
    @rollups = @worlds.index_with do |world|
      Skills::Rollup.new(builder.nodes_for_world(world))
    end
    @next_topic = builder.next_topic
  end

  def show
    @world = World.published.find_by_slug!(params[:id])
    builder = Skills::TreeBuilder.new(user: current_user)

    @nodes = builder.nodes_for_world(@world)
    @rollup = Skills::Rollup.new(@nodes)

    # Domains are CurriculumModule today; the audit proposes promoting them
    # above Skill (D1). Until then a world page groups by the module a skill's
    # missions belong to, falling back to the skill itself.
    @domains = CurriculumModule.published.where(world: @world).ordered
                               .includes(:topics)
    @boss_battles = @world.boss_battles.published
  end
end
