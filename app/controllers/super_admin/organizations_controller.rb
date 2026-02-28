class SuperAdmin::OrganizationsController < SuperAdmin::BaseController
  before_action :set_organization, only: [ :show, :edit, :update, :destroy ]

  def index
    @organizations = Organization.includes(:plan, :subscription).order(created_at: :desc)
  end

  def show
  end

  def new
    @organization = Organization.new(active: true)
  end

  def create
    @organization = Organization.new(organization_params)
    if @organization.save
      redirect_to super_admin_organization_path(@organization), notice: "조직이 생성되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @organization.update(organization_params)
      redirect_to super_admin_organization_path(@organization), notice: "조직 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @organization.destroy
      redirect_to super_admin_organizations_path, notice: "조직이 삭제되었습니다."
    else
      redirect_to super_admin_organizations_path, alert: @organization.errors.full_messages.to_sentence
    end
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(:name, :subdomain, :active, :plan_id, :stripe_customer_id)
  end
end
