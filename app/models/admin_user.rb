class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :rememberable, :validatable

  ROLES = %w[admin pd].freeze

  validates :role, inclusion: { in: ROLES }

  def admin?
    role == "admin"
  end

  def pd?
    role == "pd"
  end
end
