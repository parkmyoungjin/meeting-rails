class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :organization

  enum :role, { member: 0, org_admin: 1 }, default: :member

  def admin?
    org_admin?
  end
end
