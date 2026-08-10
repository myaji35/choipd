class Admin::ReferralsController < Admin::BaseController
  def index
    @referred = Member.where.not(referrer_id: nil).includes(:referrer).order(created_at: :desc)

    referral_counts = Member.where.not(referrer_id: nil).group(:referrer_id).count
    @referrer_stats = Member.where(id: referral_counts.keys).pluck(:id, :name).map do |id, name|
      { name: name, count: referral_counts.fetch(id) }
    end
  end
end
