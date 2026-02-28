class Plan < ApplicationRecord
  has_many :subscriptions
  has_many :organizations

  validates :name, presence: true, uniqueness: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  # room_limit: nil = 무제한
end
