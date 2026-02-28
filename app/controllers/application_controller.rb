class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_organization

  def current_organization
    Current.organization
  end

  private

  def set_current_tenant
    subdomain = request.subdomain.presence
    return unless subdomain

    Current.organization = Organization.find_by!(subdomain: subdomain, active: true)
  rescue ActiveRecord::RecordNotFound
    redirect_to root_url(subdomain: false), alert: "존재하지 않는 조직입니다."
  end
end
