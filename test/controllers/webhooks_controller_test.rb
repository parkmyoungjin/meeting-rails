require "test_helper"
require "ostruct"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "checkout.session.completed updates organization plan and subscription" do
    free = Plan.create!(name: "free_test", price_cents: 0, room_limit: 2)
    basic = Plan.create!(name: "basic_test", price_cents: 29_000, room_limit: 10, stripe_price_id: "price_basic_test")
    org = Organization.create!(name: "Webhook Org", subdomain: "webhook-org", active: true, plan: free)

    session = OpenStruct.new(
      metadata: { "organization_id" => org.id.to_s, "plan_id" => basic.id.to_s },
      subscription: "sub_123"
    )
    event = OpenStruct.new(type: "checkout.session.completed", data: OpenStruct.new(object: session))
    stripe_sub = OpenStruct.new(id: "sub_123", status: "active", current_period_end: Time.current.to_i + 7.days.to_i)

    stub_class_method(Stripe::Webhook, :construct_event, event) do
      stub_class_method(Stripe::Subscription, :retrieve, stripe_sub) do
        post "/webhooks/stripe", params: "{}", headers: webhook_headers
      end
    end

    assert_response :success
    assert_equal basic.id, org.reload.plan_id
    assert_equal "sub_123", org.subscription.reload.stripe_subscription_id
    assert_equal "active", org.subscription.status
  end

  test "customer.subscription.updated synchronizes plan from stripe price" do
    free = Plan.create!(name: "free_test2", price_cents: 0, room_limit: 2)
    pro = Plan.create!(name: "pro_test2", price_cents: 99_000, room_limit: nil, stripe_price_id: "price_pro_test")
    org = Organization.create!(name: "Webhook Org 2", subdomain: "webhook-org-2", active: true, plan: free)
    org.create_subscription!(
      plan: free,
      stripe_subscription_id: "sub_update_123",
      status: "active",
      current_period_end: 1.month.from_now
    )

    stripe_sub = OpenStruct.new(
      id: "sub_update_123",
      status: "active",
      current_period_end: 2.months.from_now.to_i,
      items: OpenStruct.new(data: [OpenStruct.new(price: OpenStruct.new(id: "price_pro_test"))])
    )
    event = OpenStruct.new(type: "customer.subscription.updated", data: OpenStruct.new(object: stripe_sub))

    stub_class_method(Stripe::Webhook, :construct_event, event) do
      post "/webhooks/stripe", params: "{}", headers: webhook_headers
    end

    assert_response :success
    assert_equal pro.id, org.reload.plan_id
    assert_equal pro.id, org.subscription.reload.plan_id
  end

  test "invalid stripe signature returns bad request" do
    stub_class_method(Stripe::Webhook, :construct_event, ->(*) { raise Stripe::SignatureVerificationError.new("invalid", "sig") }) do
      post "/webhooks/stripe", params: "{}", headers: webhook_headers
    end

    assert_response :bad_request
  end

  test "webhook endpoint accepts request without browser user agent" do
    event = OpenStruct.new(type: "unknown.event", data: OpenStruct.new(object: OpenStruct.new))

    stub_class_method(Stripe::Webhook, :construct_event, event) do
      post "/webhooks/stripe", params: "{}", headers: {
        "HTTP_STRIPE_SIGNATURE" => "test_signature",
        "CONTENT_TYPE" => "application/json"
      }
    end

    assert_response :success
  end

  private

  def webhook_headers
    {
      "HTTP_STRIPE_SIGNATURE" => "test_signature",
      "CONTENT_TYPE" => "application/json",
      "HTTP_USER_AGENT" => "Mozilla/5.0 Chrome/120.0.0.0 Safari/537.36"
    }
  end
end
