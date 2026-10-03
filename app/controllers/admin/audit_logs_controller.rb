module Admin
  class AuditLogsController < BaseController
    def index
      authorize AuditLog, :index?
      @logs = AuditLog.includes(:actor).recent.page(params[:page]).per(40)
      @logs = @logs.where(action: params[:action_name]) if params[:action_name].present?
      @actions = AuditLog.distinct.pluck(:action).sort
    end
  end
end
