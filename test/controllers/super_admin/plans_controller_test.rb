require "test_helper"

class SuperAdmin::PlansControllerTest < ActionDispatch::IntegrationTest
  test "creates plan with valid basic auth" do
    assert_difference("Plan.count", 1) do
      post super_admin_plans_path,
           params: {
             plan: {
               name: "enterprise",
               price_cents: 199_000,
               room_limit: nil,
               stripe_price_id: "price_enterprise_test"
             }
           },
           headers: basic_auth_header
    end

    assert_redirected_to super_admin_plan_path(Plan.order(:id).last)
  end

  test "prevents deleting plan used by organization" do
    plan = plans(:free)
    assert_no_difference("Plan.count") do
      delete super_admin_plan_path(plan), headers: basic_auth_header
    end

    assert_redirected_to super_admin_plans_path
  end

  private

  def basic_auth_header(username = "admin", password = "password")
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
    }
  end
end
