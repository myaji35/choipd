# /s/:hash_code → 내부 target_path 로 리다이렉트.
# 오픈 리다이렉터 방지: ShortLink.safe_target? 통과한 경로만 저장됨.
class ShortLinksController < ApplicationController
  def show
    link = ShortLink.find_by(hash_code: params[:hash_code])
    if link && ShortLink.safe_target?(link.target_path)
      link.record_click!
      redirect_to link.target_path, status: :moved_permanently, allow_other_host: false
    else
      redirect_to root_path, status: :not_found, alert: "짧은 링크를 찾을 수 없습니다"
    end
  end
end
