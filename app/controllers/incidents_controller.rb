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

      Labs::Completion.new(
        user: current_user, lab_key: "incidents",
        xp: @incident[:xp_reward] || 200,
        reason: "Resolved Production Incident: #{@incident[:title]}",
        detail: @incident[:slug]
      ).call

      flash[:notice] = "🏆 Incident resolved! #{chosen_opt[:reason]} (+#{@incident[:xp_reward]} XP)"
    else
      reason = chosen_opt ? chosen_opt[:reason] : "Select a remediation option to apply."
      flash[:alert] = "Remediation failed: #{reason}"
    end

    redirect_to incident_path(@incident[:slug])
  end
end
