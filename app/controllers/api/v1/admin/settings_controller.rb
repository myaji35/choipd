module Api
  module V1
    module Admin
      class SettingsController < BaseController
        def show
          settings = Setting.where(tenant_id: tenant_id).pluck(:key, :value).to_h
          render_success(settings)
        end

        def update
          updates = params.require(:settings).permit!.to_h
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
