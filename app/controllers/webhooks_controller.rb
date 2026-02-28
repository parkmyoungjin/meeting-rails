class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def stripe
    payload    = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

    event = Stripe::Webhook.construct_event(
      payload, sig_header, stripe_webhook_secret
    )

    case event.type
    when "checkout.session.completed"
      handle_checkout_completed(event.data.object)
    when "customer.subscription.updated"
      handle_subscription_updated(event.data.object)
    when "customer.subscription.deleted"
      handle_subscription_canceled(event.data.object)
    when "invoice.payment_failed"
      handle_payment_failed(event.data.object)
    end

    render json: { received: true }
  rescue JSON::ParserError, Stripe::SignatureVerificationError, KeyError
    head :bad_request
  end

  private

  def handle_checkout_completed(session)
    org = Organization.find_by(id: session.metadata["organization_id"])
    return unless org

    ::StripeSubscriptionSync.new(organization: org).sync_from_checkout_session(session)
  end

  def handle_subscription_updated(stripe_sub)
    sub = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
    return unless sub

    ::StripeSubscriptionSync.new(organization: sub.organization).sync_from_subscription(stripe_sub)
  end

  def handle_subscription_canceled(stripe_sub)
    sub = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
    sub&.update!(status: "canceled")
  end

  def handle_payment_failed(invoice)
    sub = Subscription.find_by(stripe_subscription_id: invoice.subscription)
    sub&.update!(status: "past_due")
  end

  def stripe_webhook_secret
    return ENV["STRIPE_WEBHOOK_SECRET"] if ENV["STRIPE_WEBHOOK_SECRET"].present?

    env_file = Rails.root.join(".env")
    raise KeyError, "key not found: STRIPE_WEBHOOK_SECRET" unless File.exist?(env_file)

    line = File.readlines(env_file).find { |item| item.start_with?("STRIPE_WEBHOOK_SECRET=") }
    secret = line.to_s.split("=", 2).last.to_s.strip
    raise KeyError, "key not found: STRIPE_WEBHOOK_SECRET" if secret.blank?

    secret
  end

end
