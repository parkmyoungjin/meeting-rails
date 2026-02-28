class Reservation < ApplicationRecord
  belongs_to :room
  belongs_to :organization

  has_secure_password
  validates :password, length: { minimum: 4 }, allow_nil: true

  validates :date, :start_time, :end_time, :organizer, :purpose, presence: true
  validates :date, comparison: { greater_than_or_equal_to: -> { Date.current } }
  validate  :end_after_start
  validate  :no_time_overlap

  before_validation :set_organization

  private

  def set_organization
    self.organization_id = room.organization_id if room
  end

  def end_after_start
    return unless start_time && end_time
    errors.add(:end_time, "는 시작 시간보다 늦어야 합니다.") if end_time <= start_time
  end

  def no_time_overlap
    return unless room && date && start_time && end_time
    overlapping = Reservation.where(room_id: room_id, date: date)
                             .where.not(id: id)
                             .where("start_time < ? AND end_time > ?", end_time, start_time)
                             .lock
    errors.add(:base, "해당 시간에 이미 예약이 있습니다.") if overlapping.exists?
  end
end
