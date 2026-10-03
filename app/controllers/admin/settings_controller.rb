module Admin
  # Branding is configurable rather than hard-coded, so the working name can be
  # replaced without a deploy.
  class SettingsController < BaseController
    EDITABLE = %w[product_name tagline accent_color support_email registration_open].freeze

    def show
      authorize AppSetting, :index?
      @settings = EDITABLE.index_with { |key| AppSetting[key] }
    end

    def update
      authorize AppSetting, :update?
      submitted = params.fetch(:settings, {}).permit(*EDITABLE).to_h

      submitted.each do |key, value|
        next unless EDITABLE.include?(key)

        AppSetting.set!(key, cast(key, value))
      end

      audit!("admin.settings.update", metadata: { "keys" => submitted.keys })
      redirect_to admin_settings_path, notice: "Settings saved."
    end

    private

    def cast(key, value)
      return ActiveModel::Type::Boolean.new.cast(value) if key == "registration_open"

      value.to_s.strip
    end
  end
end
