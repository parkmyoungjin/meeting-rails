require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "create redirects to tenant admin subdomain" do
    assert_difference("Organization.count", 1) do
      assert_difference("User.count", 1) do
        post registrations_path, params: {
          organization: { name: "Redirect Org", subdomain: "redirect-org" },
          user: {
            email: "redirect-admin@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
    end

    assert_redirected_to "http://redirect-org.localhost/admin"
  end

  test "subdomain availability returns unavailable for existing subdomain" do
    get subdomain_availability_registrations_path, params: { subdomain: "demo" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "demo", body["subdomain"]
    assert_equal false, body["available"]
  end

  test "subdomain availability normalizes and validates candidate" do
    get subdomain_availability_registrations_path, params: { subdomain: "  New-Hospital  " }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "new-hospital", body["subdomain"]
    assert_equal true, body["available"]
  end

  test "subdomain availability rejects invalid format" do
    get subdomain_availability_registrations_path, params: { subdomain: "bad_domain!" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal false, body["available"]
  end
end
