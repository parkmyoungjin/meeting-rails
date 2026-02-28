class AddSubscriptionUniquenessIndexes < ActiveRecord::Migration[8.1]
  def change
    unless index_exists?(:subscriptions, :organization_id, unique: true, name: "index_subscriptions_on_organization_id")
      remove_index :subscriptions, name: "index_subscriptions_on_organization_id" if index_exists?(:subscriptions, :organization_id, name: "index_subscriptions_on_organization_id")
      add_index :subscriptions, :organization_id, unique: true, name: "index_subscriptions_on_organization_id"
    end

    unless index_exists?(:subscriptions, :stripe_subscription_id, unique: true, name: "index_subscriptions_on_stripe_subscription_id")
      remove_index :subscriptions, name: "index_subscriptions_on_stripe_subscription_id" if index_exists?(:subscriptions, :stripe_subscription_id, name: "index_subscriptions_on_stripe_subscription_id")
      add_index :subscriptions, :stripe_subscription_id, unique: true, where: "stripe_subscription_id IS NOT NULL", name: "index_subscriptions_on_stripe_subscription_id"
    end
  end
end
