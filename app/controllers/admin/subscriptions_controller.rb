class Admin::SubscriptionsController < Admin::BaseController
  def show
    @billing_error = nil
    reconcile_checkout_session if params[:session_id].present?
    @subscription = Current.organization.subscription
    @current_plan = Current.organization.plan
    @plans        = Plan.all.order(:price_cents)
    @invoices     = fetch_recent_invoices
  end

  def create
    plan = Plan.find(params[:plan_id])

    if plan.price_cents == 0
      # 무료 플랜: 바로 적용
      apply_free_plan(plan)
      redirect_to admin_subscription_path, notice: "#{plan.name} 플랜으로 변경되었습니다."
    else
      if plan.stripe_price_id.blank?
        redirect_to admin_subscription_path, alert: "선택한 플랜의 Stripe 가격 정보가 없습니다. 관리자에게 문의하세요."
        return
      end

      # 유료 플랜: Stripe Checkout
      session_obj = create_stripe_checkout(plan)
      redirect_to session_obj.url, allow_other_host: true
    end
  rescue Stripe::StripeError => e
    redirect_to admin_subscription_path, alert: "결제 세션 생성에 실패했습니다: #{e.message}"
  end

  def destroy
    sub = Current.organization.subscription
    if sub&.stripe_subscription_id.present?
      Stripe::Subscription.cancel(sub.stripe_subscription_id)
    end
    sub&.update!(status: "canceled")
    redirect_to admin_subscription_path, notice: "구독이 취소되었습니다."
  rescue Stripe::StripeError => e
    redirect_to admin_subscription_path, alert: "구독 취소에 실패했습니다: #{e.message}"
  end

  private

  def apply_free_plan(plan)
    org = Current.organization
    org.update!(plan: plan)
    if org.subscription&.stripe_subscription_id.present?
      Stripe::Subscription.cancel(org.subscription.stripe_subscription_id)
      org.subscription.update!(status: "canceled")
    end
    org.subscription&.destroy
    org.create_subscription!(
      plan:               plan,
      status:             "active",
      current_period_end: 100.years.from_now
    )
  end

  def create_stripe_checkout(plan)
    org = Current.organization
    customer_id = ensure_stripe_customer(org)

    Stripe::Checkout::Session.create(
      mode:       "subscription",
      customer:   customer_id,
      line_items: [ { price: plan.stripe_price_id, quantity: 1 } ],
      client_reference_id: org.id.to_s,
      success_url: admin_subscription_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url:  admin_subscription_url,
      metadata:    { organization_id: org.id, plan_id: plan.id }
    )
  end

  def ensure_stripe_customer(org)
    return org.stripe_customer_id if org.stripe_customer_id.present?
    customer = Stripe::Customer.create(email: current_user.email, name: org.name)
    org.update!(stripe_customer_id: customer.id)
    customer.id
  end

  def fetch_recent_invoices
    customer_id = Current.organization.stripe_customer_id
    return [] if customer_id.blank?

    Stripe::Invoice.list(customer: customer_id, limit: 10).data
  rescue Stripe::StripeError => e
    @billing_error = e.message
    []
  end

  def reconcile_checkout_session
    session = Stripe::Checkout::Session.retrieve(
      { id: params[:session_id], expand: [ "subscription" ] }
    )
    return unless session.mode == "subscription"
    return unless session.metadata&.[]("organization_id").to_s == Current.organization.id.to_s

    synced = ::StripeSubscriptionSync.new(organization: Current.organization).sync_from_checkout_session(session)
    flash.now[:notice] = "결제가 확인되어 구독 상태를 동기화했습니다." if synced
  rescue Stripe::StripeError => e
    @billing_error = e.message
  end
end
