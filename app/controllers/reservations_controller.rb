class ReservationsController < ApplicationController
  before_action :set_current_tenant
  before_action :set_reservation, only: [ :show, :edit, :update, :destroy, :verify, :authenticate ]

  def index
    @date   = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @floors = Current.organization.rooms.active.distinct.pluck(:floor).sort
    @floor  = params[:floor] || @floors.first
    @rooms  = @floor ? Current.organization.rooms.active.where(floor: @floor) : []
    @reservations = @floor ? Reservation.where(room: @rooms, date: @date)
                                        .includes(:room)
                                        .order(:start_time) : []
  end

  def show
  end

  def new
    @room = Current.organization.rooms.active.find(params[:room_id])
    @reservation = @room.reservations.new(
      date:       params[:date] || Date.current,
      start_time: params[:start_time]
    )
  end

  def create
    @room = Current.organization.rooms.active.find(reservation_params[:room_id])
    @reservation = @room.reservations.new(reservation_params)
    if @reservation.save
      redirect_to reservation_path(@reservation), notice: "예약이 완료되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def verify
    # GET: 비밀번호 입력 폼
  end

  def authenticate
    if @reservation.authenticate(params[:password])
      session[:authenticated_reservation_id] = @reservation.id
      redirect_to edit_reservation_path(@reservation)
    else
      flash.now[:alert] = "비밀번호가 올바르지 않습니다."
      render :verify, status: :unprocessable_entity
    end
  end

  def edit
    unless session[:authenticated_reservation_id] == @reservation.id
      return redirect_to verify_reservation_path(@reservation)
    end
  end

  def update
    unless session[:authenticated_reservation_id] == @reservation.id
      return redirect_to verify_reservation_path(@reservation)
    end
    if @reservation.update(update_params)
      session.delete(:authenticated_reservation_id)
      redirect_to reservation_path(@reservation), notice: "예약이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless session[:authenticated_reservation_id] == @reservation.id
      return redirect_to verify_reservation_path(@reservation)
    end
    @reservation.destroy
    session.delete(:authenticated_reservation_id)
    redirect_to reservations_path, notice: "예약이 삭제되었습니다."
  end

  private

  def set_reservation
    @reservation = Current.organization.reservations.find(params[:id])
  end

  def reservation_params
    params.require(:reservation).permit(
      :room_id, :date, :start_time, :end_time,
      :organizer, :purpose, :password, :password_confirmation
    )
  end

  def update_params
    params.require(:reservation).permit(:organizer, :purpose, :start_time, :end_time)
  end
end
