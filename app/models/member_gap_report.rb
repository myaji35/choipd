class MemberGapReport < ApplicationRecord
  belongs_to :member

  validates :profession, :radar_self, :radar_median, :radar_top10, presence: true

  def radar_self_data
    JSON.parse(radar_self || "{}") rescue {}
  end

  def radar_median_data
    JSON.parse(radar_median || "{}") rescue {}
  end

  def radar_top10_data
    JSON.parse(radar_top10 || "{}") rescue {}
  end

  def gaps
    JSON.parse(gaps_json || "[]") rescue []
  end

  def opportunities
    JSON.parse(opportunities_json || "[]") rescue []
  end

  def growth_path
    JSON.parse(growth_path_json || "[]") rescue []
  end
end
