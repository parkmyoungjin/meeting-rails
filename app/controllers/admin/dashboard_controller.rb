class Admin::DashboardController < Admin::BaseController
  def index
    @total_rooms        = Current.organization.rooms.active.count
    @today_reservations = Current.organization.reservations.where(date: Date.current).count
    @this_month         = Current.organization.reservations
                                 .where(date: Date.current.beginning_of_month..Date.current.end_of_month)
                                 .count
    @recent_reservations = Current.organization.reservations
                                  .includes(:room)
                                  .order(created_at: :desc)
                                  .limit(10)
  end
end
