class Organization < ApplicationRecord
  SUBDOMAIN_FORMAT = /\A[a-z0-9\-]+\z/

  has_many :users, dependent: :destroy
  has_many :rooms, dependent: :destroy
  has_many :reservations, through: :rooms
  has_one  :subscription, dependent: :destroy
  belongs_to :plan, optional: true

  before_validation :normalize_subdomain!

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true,
            length: { in: 3..63 },
            format: { with: SUBDOMAIN_FORMAT, message: "소문자, 숫자, 하이픈만 허용됩니다." }
  validates :active, inclusion: { in: [ true, false ] }

  def self.normalize_subdomain(value)
    value.to_s.strip.downcase
  end

  def self.subdomain_available?(value)
    candidate = normalize_subdomain(value)
    return false if candidate.blank?
    return false unless candidate.length.between?(3, 63)
    return false unless candidate.match?(SUBDOMAIN_FORMAT)

    !exists?(subdomain: candidate)
  end

  private

  def normalize_subdomain!
    self.subdomain = self.class.normalize_subdomain(subdomain)
  end
end
