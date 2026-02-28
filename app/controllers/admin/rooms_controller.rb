class Admin::RoomsController < Admin::BaseController
  before_action :set_room, only: [ :edit, :update, :destroy ]
  before_action :check_room_limit, only: [ :create ]

  def index
    @rooms = Current.organization.rooms.order(:floor, :name)
  end

  def new
    @room = Current.organization.rooms.new
  end

  def create
    @room = Current.organization.rooms.new(room_params)
    if @room.save
      redirect_to admin_rooms_path, notice: "회의실이 추가되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @room.update(room_params)
      redirect_to admin_rooms_path, notice: "회의실이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @room.update!(active: false)
    redirect_to admin_rooms_path, notice: "회의실이 비활성화되었습니다."
  end

  private

  def set_room
    @room = Current.organization.rooms.find(params[:id])
  end

  def room_params
    params.require(:room).permit(:floor, :name, :capacity, :active)
  end

  def check_room_limit
    plan  = Current.organization.plan
    limit = plan&.room_limit
    return unless limit
    if Current.organization.rooms.active.count >= limit
      redirect_to admin_rooms_path,
        alert: "현재 플랜(#{plan.name}, #{limit}개 한도)의 회의실 한도에 도달했습니다. 플랜을 업그레이드하세요."
    end
  end
end
