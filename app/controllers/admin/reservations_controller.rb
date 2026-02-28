class Admin::ReservationsController < Admin::BaseController
  def index
    @date   = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @reservations = Current.organization.reservations
                           .includes(:room)
                           .where(date: @date)
                           .order(:start_time)
  end

  def destroy
    @reservation = Current.organization.reservations.find(params[:id])
    @reservation.destroy
    redirect_to admin_reservations_path, notice: "예약이 삭제되었습니다."
  end
end
