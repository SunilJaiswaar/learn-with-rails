class IncidentsController < ApplicationController
  before_action :require_authentication

  def index
    @incidents = Incidents::Catalogue.all
  end

  def show
    @incident = Incidents::Catalogue.find_by_slug(params[:id])
    redirect_to incidents_path, alert: "Incident not found." unless @incident

    session[:resolved_incidents] ||= []
    @resolved = session[:resolved_incidents].include?(@incident[:slug])
  end

  def resolve
    @incident = Incidents::Catalogue.find_by_slug(params[:id])
    return redirect_to incidents_path unless @incident

    chosen_id = params[:remediation_id].to_s
    chosen_opt = @incident[:options].find { |o| o[:id] == chosen_id }

    session[:resolved_incidents] ||= []

    if chosen_opt && chosen_opt[:correct]
      session[:resolved_incidents] << @incident[:slug] unless session[:resolved_incidents].include?(@incident[:slug])

      skill = Skill.find_by(slug: "debugging-skill") || Skill.first
      Mastery::Recorder.new(
        user: current_user,
        skill: skill,
        dimension: :debugging,
        score: 95
      ).call

      Gamification::XpAward.new(
        user: current_user,
        amount: @incident[:xp_reward] || 200,
        reason: "Resolved Production Incident: #{@incident[:title]}",
        idempotency_key: "incident-#{@incident[:slug]}-#{current_user.id}"
      ).call

      flash[:notice] = "🏆 Incident resolved! #{chosen_opt[:reason]} (+#{@incident[:xp_reward]} XP)"
    else
      reason = chosen_opt ? chosen_opt[:reason] : "Select a remediation option to apply."
      flash[:alert] = "Remediation failed: #{reason}"
    end

    redirect_to incident_path(@incident[:slug])
  end
end
