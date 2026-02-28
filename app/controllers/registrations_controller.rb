class RegistrationsController < ApplicationController
  def new
    @organization = Organization.new
    @user         = User.new
    @base_domain  = ENV.fetch("APP_DOMAIN", "myapp.com")
  end

  def create
    @organization = Organization.new(org_params)
    @user         = User.new(user_params.merge(role: :org_admin, organization: @organization))

    ActiveRecord::Base.transaction do
      free_plan = Plan.find_by!(name: "free")
      @organization.plan = free_plan
      @organization.save!
      @user.save!
      @organization.create_subscription!(
        plan:               free_plan,
        status:             "active",
        current_period_end: 100.years.from_now
      )
    end

    sign_in(:user, @user)
    redirect_to admin_root_url(subdomain: @organization.subdomain),
                allow_other_host: true,
                notice: "가입을 환영합니다! 회의실을 먼저 추가해 보세요."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    @base_domain = ENV.fetch("APP_DOMAIN", "myapp.com")
    render :new, status: :unprocessable_entity
  end

  def subdomain_availability
    subdomain = Organization.normalize_subdomain(params[:subdomain])
    available = Organization.subdomain_available?(subdomain)

    render json: {
      subdomain: subdomain,
      available: available,
      message: subdomain_message(subdomain, available)
    }
  end

  private

  def org_params
    params.require(:organization).permit(:name, :subdomain)
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def subdomain_message(subdomain, available)
    return "서브도메인을 입력해 주세요." if subdomain.blank?
    return "3~63자로 입력해 주세요." unless subdomain.length.between?(3, 63)
    return "소문자, 숫자, 하이픈만 사용 가능합니다." unless subdomain.match?(Organization::SUBDOMAIN_FORMAT)
    return "사용 가능한 서브도메인입니다." if available

    "이미 사용 중인 서브도메인입니다."
  end
end
