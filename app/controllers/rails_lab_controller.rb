# The Rails request-lifecycle lab (spec 109).
#
# Rails is usually taught as a list of APIs. This renders it as a machine: a
# request is traced through Puma, the real middleware stack of this very
# application, the router, the controller, the model, the database, the view
# and back out — and the learner can inject a specific failure and see which
# layer reacts.
class RailsLabController < ApplicationController
  before_action :require_authentication

  def show
    load_lab
  end

  def trace
    load_lab

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to rails_lab_path(trace_params) }
    end
  end

  def solve
    load_lab
    @challenge = RailsLab::Challenges.find(params[:slug])
    return redirect_to rails_lab_path unless @challenge

    @chosen = params[:stage].to_s
    @correct = RailsLab::Challenges.correct?(@challenge, @chosen)
    notice = @correct ? award(@challenge) : nil
    record_miss(@challenge) unless @correct
    # Recomputed after awarding: the count was loaded before the new ledger
    # entry existed, so the board rendered one behind.
    @solved_slugs = solved_slugs

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = notice if notice }
      format.html { redirect_to rails_lab_path, notice: notice }
    end
  end

  private

  def load_lab
    @result = RailsLab::Pipeline.new(**trace_params.symbolize_keys).call
    @middleware = RailsLab::MiddlewareStack.entries
    @conditions = RailsLab::Pipeline::CONDITIONS
    @challenges = RailsLab::Challenges.all
    @solved_slugs = solved_slugs
  end

  def trace_params
    {
      verb: params[:verb].presence || "GET",
      path: params[:path].presence || "/skills/sql-joins",
      condition: params[:condition].presence,
      query: params[:query].presence
    }
  end

  # Read from the ledger rather than the session, so a solved challenge
  # survives a new browser and cannot be un-solved by clearing cookies.
  def solved_slugs
    keys = RailsLab::Challenges.slugs.map { |slug| "lab:rails_lab:#{slug}" }
    current_user.xp_transactions.where(idempotency_key: keys)
                .pluck(:idempotency_key)
                .map { |key| key.split(":").last }
                .to_set
  end

  def award(challenge)
    outcome = Labs::Completion.new(
      user: current_user, lab_key: "rails_lab",
      xp: challenge[:xp_reward],
      reason: "Rails Lab: #{challenge[:title]}",
      detail: challenge[:slug]
    ).call

    return nil unless outcome.xp.positive?

    "🚂 Correct — #{challenge[:title]} (+#{outcome.xp} XP)"
  end

  # A wrong answer is still an attempt, so guessing lowers the running score
  # rather than costing nothing.
  def record_miss(_challenge)
    skill = Labs::Catalogue.skill_for("rails_lab")
    return if skill.nil?

    Mastery::Recorder.new(
      user: current_user, skill: skill, dimension: :understanding,
      score: 0, correct: false
    ).call
  end
end
