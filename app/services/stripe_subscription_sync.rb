class StripeSubscriptionSync
  def initialize(organization:)
    @organization = organization
  end

  def sync_from_checkout_session(session)
    return false unless session&.subscription.present?

    plan = plan_from_session(session)
    return false unless plan

    stripe_sub = extract_subscription(session.subscription)
    persist_subscription!(plan: plan, stripe_sub: stripe_sub)
    true
  end

  def sync_from_subscription(stripe_sub)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
    return false unless subscription

    plan = plan_from_subscription(stripe_sub) || subscription.plan

    subscription.update!(
      plan:               plan,
      status:             normalized_status(stripe_sub.status),
      current_period_end: to_timestamp(stripe_sub.current_period_end)
    )
    subscription.organization.update!(plan: plan) if subscription.organization.plan_id != plan.id
    true
  end

  private

  attr_reader :organization

  def persist_subscription!(plan:, stripe_sub:)
    Subscription.transaction do
      organization.update!(plan: plan)
      subscription = organization.subscription || organization.build_subscription
      subscription.assign_attributes(
        plan:                   plan,
        stripe_subscription_id: stripe_sub.id,
        status:                 normalized_status(stripe_sub.status),
        current_period_end:     to_timestamp(stripe_sub.current_period_end)
      )
      subscription.save!
    end
  end

  def extract_subscription(subscription_payload)
    return subscription_payload if subscription_payload.respond_to?(:id)

    Stripe::Subscription.retrieve(subscription_payload)
  end

  def plan_from_session(session)
    plan = Plan.find_by(id: session.metadata&.[]("plan_id"))
    return plan if plan

    stripe_sub = extract_subscription(session.subscription)
    plan_from_subscription(stripe_sub)
  end

  def plan_from_subscription(stripe_sub)
    price_id = stripe_sub.items&.data&.first&.price&.id
    return if price_id.blank?

    Plan.find_by(stripe_price_id: price_id)
  end

  def normalized_status(status)
    Subscription::STATUSES.include?(status) ? status : "past_due"
  end

  def to_timestamp(unix_time)
    return if unix_time.blank?

    Time.zone.at(unix_time)
  end
end
