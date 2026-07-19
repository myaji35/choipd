require "base64"
require "json"
require "securerandom"

class MemberAdmin::FacebookConnectionsController < MemberAdmin::BaseController
  def connect
    unless FacebookOauth.configured?
      redirect_to sns_accounts_path, alert: "페이스북 앱 연동이 아직 설정되지 않았습니다(관리자 문의)."
      return
    end

    nonce = SecureRandom.urlsafe_base64(32)
    session[:facebook_oauth_nonce] = nonce
    state = Base64.urlsafe_encode64({ slug: @member.slug, nonce: nonce }.to_json, padding: false)

    redirect_to FacebookOauth.authorize_url(redirect_uri: callback_url, state: state), allow_other_host: true
  end

  def callback
    unless valid_state?(params[:state])
      clear_oauth_session
      redirect_to sns_accounts_path, alert: "페이스북 연결 요청을 확인할 수 없습니다. 다시 시도해 주세요."
      return
    end

    session.delete(:facebook_oauth_nonce)
    user_access_token = FacebookOauth.exchange_code(code: params[:code], redirect_uri: callback_url) if params[:code].present?
    unless user_access_token.present?
      clear_oauth_session
      redirect_to sns_accounts_path, alert: "페이스북 인증에 실패했습니다. 다시 시도해 주세요."
      return
    end

    pages = FacebookOauth.list_pages(user_access_token: user_access_token)
    session[:facebook_user_access_token] = user_access_token if pages.any?
    @pages = pages.map { |page| page.slice(:id, :name) }
  end

  def save_page
    user_access_token = session[:facebook_user_access_token]
    unless user_access_token.present?
      redirect_to sns_accounts_path, alert: "페이스북 연결 시간이 만료되었습니다. 다시 연결해 주세요."
      return
    end

    page = FacebookOauth.list_pages(user_access_token: user_access_token).find do |candidate|
      ActiveSupport::SecurityUtils.secure_compare(candidate[:id].to_s, params[:page_id].to_s)
    end
    clear_oauth_session

    unless page
      redirect_to sns_accounts_path, alert: "선택한 페이스북 페이지를 확인할 수 없습니다. 다시 연결해 주세요."
      return
    end

    account = @member.sns_accounts.find_or_initialize_by(platform: "facebook", account_name: page[:name])
    account.access_token = page[:access_token]
    account.is_active = true

    if account.save
      redirect_to sns_accounts_path, notice: "페이스북 페이지를 연결했습니다."
    else
      redirect_to sns_accounts_path, alert: account.errors.full_messages.join(", ")
    end
  end

  private

  def sns_accounts_path
    slug_admin_sns_accounts_path(slug: @member.slug)
  end

  def callback_url
    slug_admin_facebook_callback_url(slug: @member.slug)
  end

  def valid_state?(encoded_state)
    state = JSON.parse(Base64.urlsafe_decode64(encoded_state.to_s)).with_indifferent_access
    expected_nonce = session[:facebook_oauth_nonce].to_s
    nonce = state[:nonce].to_s

    state[:slug] == @member.slug && expected_nonce.present? &&
      nonce.bytesize == expected_nonce.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(nonce, expected_nonce)
  rescue ArgumentError, JSON::ParserError
    false
  end

  def clear_oauth_session
    session.delete(:facebook_oauth_nonce)
    session.delete(:facebook_user_access_token)
  end
end
