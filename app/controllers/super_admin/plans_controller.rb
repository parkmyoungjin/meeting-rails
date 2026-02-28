class SuperAdmin::PlansController < SuperAdmin::BaseController
  before_action :set_plan, only: [ :show, :edit, :update, :destroy ]

  def index
    @plans = Plan.order(price_cents: :asc)
  end

  def show
  end

  def new
    @plan = Plan.new
  end

  def create
    @plan = Plan.new(plan_params)
    if @plan.save
      redirect_to super_admin_plan_path(@plan), notice: "플랜이 생성되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plan.update(plan_params)
      redirect_to super_admin_plan_path(@plan), notice: "플랜이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @plan.organizations.exists? || @plan.subscriptions.exists?
      redirect_to super_admin_plans_path, alert: "사용 중인 플랜은 삭제할 수 없습니다."
      return
    end

    @plan.destroy
    redirect_to super_admin_plans_path, notice: "플랜이 삭제되었습니다."
  end

  private

  def set_plan
    @plan = Plan.find(params[:id])
  end

  def plan_params
    params.require(:plan).permit(:name, :price_cents, :room_limit, :stripe_price_id)
  end
end
