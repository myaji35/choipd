module Api
  module V1
    module Admin
      class SettingsController < BaseController
        ALLOWED_KEYS = %w[site_name site_description].freeze

        def show
          settings = Setting.where(tenant_id: tenant_id).pluck(:key, :value).to_h
          render_success(settings)
        end

        def update
          raw_settings = params.require(:settings)
          unknown_keys = raw_settings.keys - ALLOWED_KEYS
          return render_error("Unknown settings", status: :unprocessable_entity, errors: unknown_keys) if unknown_keys.any?

          updates = raw_settings.permit(*ALLOWED_KEYS).to_h
          updates.each do |k, v|
            setting = Setting.find_or_initialize_by(tenant_id: tenant_id, key: k.to_s)
            setting.value = v.to_s
            setting.save!
          end
          render_success(updates)
        end
      end
    end
  end
end
