class SystemDesignController < ApplicationController
  before_action :require_authentication

  def index
    @challenges = SystemDesign::Catalogue.all
  end

  def show
    @challenge = SystemDesign::Catalogue.find_by_slug(params[:slug])
    redirect_to system_design_index_path, alert: "System design challenge not found." unless @challenge

    @components = params[:components].present? ? Array(params[:components]) : @challenge[:initial_components]
    @rps = params[:rps].presence || @challenge[:traffic_rps]
    @failures = Array(params[:failures])

    @simulation = SystemDesign::Simulator.new(
      challenge: @challenge,
      components: @components,
      rps: @rps,
      active_failures: @failures
    ).call
  end

  def simulate
    @challenge = SystemDesign::Catalogue.find_by_slug(params[:slug])
    return head :not_found unless @challenge

    @components = Array(params[:components]).map(&:to_s).reject(&:blank?)
    @rps = [ params[:rps].to_i, 100 ].max
    @failures = Array(params[:failures]).map(&:to_s).reject(&:blank?)

    @simulation = SystemDesign::Simulator.new(
      challenge: @challenge,
      components: @components,
      rps: @rps,
      active_failures: @failures
    ).call

    if @simulation.passed
      Labs::Completion.new(
        user: current_user, lab_key: "system_design",
        xp: @challenge[:xp_reward] || 350,
        reason: "Mastered #{@challenge[:title]} System Design challenge",
        detail: @challenge[:slug]
      ).call
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to system_design_path(@challenge[:slug], components: @components, rps: @rps, failures: @failures) }
    end
  end
end
