require "test_helper"

class SuperAdmin::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  test "requires http basic auth" do
    get super_admin_organizations_path
    assert_response :unauthorized
  end

  test "lists organizations with valid basic auth" do
    get super_admin_organizations_path, headers: basic_auth_header
    assert_response :success
  end

  test "creates organization with valid basic auth" do
    plan = plans(:free)

    assert_difference("Organization.count", 1) do
      post super_admin_organizations_path,
           params: {
             organization: {
               name: "New Org",
               subdomain: "new-org",
               active: true,
               plan_id: plan.id
             }
           },
           headers: basic_auth_header
    end

    assert_redirected_to super_admin_organization_path(Organization.order(:id).last)
  end

  private

  def basic_auth_header(username = "admin", password = "password")
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
    }
  end
end
