module Admin
  # Version-aware curriculum management (spec 60).
  class TechnologyVersionsController < BaseController
    def index
      authorize TechnologyVersion, :index?
      @technologies = Technology.includes(:technology_versions).ordered
    end

    def update
      authorize TechnologyVersion, :update?
      version = TechnologyVersion.find(params[:id])
      if version.update(version_params)
        audit!("admin.technology_version.update", auditable: version)
        redirect_to admin_technology_versions_path, notice: "#{version.label} updated."
      else
        redirect_to admin_technology_versions_path,
                    alert: version.errors.full_messages.to_sentence
      end
    end

    private

    def version_params
      params.expect(technology_version: %i[number status released_on deprecated_on
                                           docs_url notes])
    end
  end
end
