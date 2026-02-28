class Room < ApplicationRecord
  belongs_to :organization
  has_many :reservations, dependent: :destroy

  scope :active, -> { where(active: true) }

  validates :name, :floor, :capacity, presence: true
  validates :capacity, numericality: { greater_than: 0, only_integer: true }
end
