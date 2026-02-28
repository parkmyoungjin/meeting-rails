class Admin::BaseController < ApplicationController
  before_action :set_current_tenant
  before_action :authenticate_user!
  before_action :require_org_admin

  layout "admin"

  private

  def require_org_admin
    unless current_user&.org_admin? &&
           current_user.organization_id == Current.organization&.id
      redirect_to root_path, alert: "관리자 권한이 필요합니다."
    end
  end
end
