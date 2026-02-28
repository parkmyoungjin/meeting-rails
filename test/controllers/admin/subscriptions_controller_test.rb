require "test_helper"
require "ostruct"

class Admin::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    host! "demo.localhost"
    sign_in users(:admin)
  end

  test "show reconciles checkout session when session_id is provided" do
    demo = organizations(:demo)
    basic = plans(:basic)

    stripe_sub = OpenStruct.new(
      id: "sub_reconcile_123",
      status: "active",
      current_period_end: 1.month.from_now.to_i,
      items: OpenStruct.new(data: [OpenStruct.new(price: OpenStruct.new(id: basic.stripe_price_id))])
    )

    session = OpenStruct.new(
      mode: "subscription",
      metadata: { "organization_id" => demo.id.to_s, "plan_id" => basic.id.to_s },
      subscription: stripe_sub
    )

    stub_class_method(Stripe::Checkout::Session, :retrieve, session) do
      get "/admin/subscription", params: { session_id: "cs_test_123" }
    end

    assert_response :success
    assert_equal basic.id, demo.reload.plan_id
    assert_equal "sub_reconcile_123", demo.subscription.reload.stripe_subscription_id
  end
end
