module Api
  module V1
    module Sns
      class SnsAccountsController < BaseController
        before_action :set_account, only: [ :show, :update, :destroy ]

        def index
          accounts = SnsAccount.where(tenant_id: tenant_id).order(:platform)
          render_success(accounts.as_json(except: [ :access_token, :refresh_token ]))
        end

        def show
          render_success(@account.as_json(except: [ :access_token, :refresh_token ]))
        end

        def create
          account = SnsAccount.new(account_params.merge(tenant_id: tenant_id))
          if account.save
            render_success(account.as_json(except: [ :access_token, :refresh_token ]), status: :created)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: account.errors.full_messages)
          end
        end

        def update
          if @account.update(account_params)
            render_success(@account.as_json(except: [ :access_token, :refresh_token ]))
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: @account.errors.full_messages)
          end
        end

        def destroy
          @account.destroy
          render_success({ id: @account.id })
        end

        private

        def set_account
          @account = SnsAccount.where(tenant_id: tenant_id).find(params[:id])
        end

        def account_params
          params.require(:sns_account).permit(:platform, :account_name, :access_token, :refresh_token, :is_active)
        end
      end
    end
  end
end
