class Subscription < ApplicationRecord
  belongs_to :organization
  belongs_to :plan

  STATUSES = %w[active past_due canceled].freeze
  validates :status, inclusion: { in: STATUSES }

  def active?
    status == "active" && (current_period_end.nil? || current_period_end > Time.current)
  end
end
