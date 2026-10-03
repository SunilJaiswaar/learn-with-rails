# Enforces the prerequisite gate (spec 50).
#
# The lock state was already computed correctly by Skills::TreeBuilder and
# rendered on the skill map, but no controller consulted it, so a locked skill
# was served to anyone who typed its URL. This closes that.
#
# What is gated and what is not is a deliberate line: **things that measure and
# reward are gated; things that explore and introduce stay open.**
#
#   gated      skills, missions, challenges, boss battles — they award XP and
#              record mastery, and their content assumes the prerequisites
#   not gated  the engineering labs, because discovering and seeing a concept
#              comes *before* understanding it (spec 3), and labs are Sandbox
#              Mode (spec 53); locking the thing that introduces you to Redis
#              behind a Redis skill is backwards
#   not gated  the interview arena, because someone interviewing tomorrow has
#              a legitimate reason to practise a question on a skill they have
#              not formally unlocked (spec 54)
#
# The gate is pedagogical scaffolding, not access control: its purpose is to
# prevent confusion, so it answers with a page explaining what to learn first
# rather than a bare refusal.
module GatesContent
  extend ActiveSupport::Concern

  private

  # Renders the "learn these first" page and returns true when the skill is
  # locked, so an action can `return if gated?(skill)`.
  def gated?(skill)
    return false if skill.nil?

    @availability = Skills::Availability.new(user: current_user, skill: skill).call
    return false if @availability.available?

    render_locked
    true
  end

  def render_locked
    respond_to do |format|
      format.html { render "shared/locked", status: :forbidden }
      format.json { render json: locked_payload, status: :forbidden }
      format.any  { head :forbidden }
    end
  end

  def locked_payload
    {
      error: "locked",
      skill: @availability.skill.slug,
      missing: @availability.missing_skills.map(&:slug),
      estimated_minutes: @availability.estimated_minutes
    }
  end
end
