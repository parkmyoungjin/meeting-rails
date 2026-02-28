class SuperAdmin::BaseController < ApplicationController
  before_action :authenticate_super_admin!
  layout "super_admin"

  private

  def authenticate_super_admin!
    username, password = super_admin_credentials

    unless username.present? && password.present?
      render plain: "SUPER_ADMIN_USERNAME / SUPER_ADMIN_PASSWORD 설정이 필요합니다.", status: :service_unavailable
      return
    end

    authenticate_or_request_with_http_basic("Super Admin") do |input_username, input_password|
      secure_compare(input_username, username) && secure_compare(input_password, password)
    end
  end

  def super_admin_credentials
    username = ENV["SUPER_ADMIN_USERNAME"].to_s
    password = ENV["SUPER_ADMIN_PASSWORD"].to_s

    return [ username, password ] if username.present? && password.present?
    return [ "admin", "password" ] if Rails.env.development? || Rails.env.test?

    [ nil, nil ]
  end

  def secure_compare(left, right)
    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(left.to_s), ::Digest::SHA256.hexdigest(right.to_s))
  end
end
