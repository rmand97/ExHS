defmodule Exhs.Billing.Subscription do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "billing_subscriptions"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
      reference :membership, on_delete: :delete
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :membership_id,
        :stripe_subscription_id,
        :stripe_customer_id,
        :status,
        :current_period_start,
        :current_period_end,
        :cancel_at_period_end
      ]
    end

    update :sync do
      accept [
        :status,
        :current_period_start,
        :current_period_end,
        :cancel_at_period_end
      ]
    end

    update :cancel do
      accept []
      change set_attribute(:cancel_at_period_end, true)
    end

    read :get_by_id do
      get_by :id
    end

    read :get_by_stripe_id do
      argument :stripe_subscription_id, :string, allow_nil?: false
      filter expr(stripe_subscription_id == ^arg(:stripe_subscription_id))
      get? true
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass Exhs.Checks.Superadmin do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin, :board]}
      authorize_if expr(membership.user_id == ^actor(:id))
    end

    policy action_type(:create) do
      forbid_if always()
    end

    policy action_type(:update) do
      forbid_if always()
    end
  end

  multitenancy do
    strategy :attribute
    attribute :forening_id
  end

  attributes do
    uuid_primary_key :id

    attribute :stripe_subscription_id, :string do
      allow_nil? false
      public? true
    end

    attribute :stripe_customer_id, :string do
      allow_nil? false
      public? true
    end

    attribute :status, Exhs.Billing.Types.SubscriptionStatus do
      allow_nil? false
      public? true
    end

    attribute :current_period_start, :utc_datetime_usec, public?: true
    attribute :current_period_end, :utc_datetime_usec, public?: true

    attribute :cancel_at_period_end, :boolean do
      allow_nil? false
      default false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :forening, Exhs.Organizations.Forening do
      allow_nil? false
    end

    belongs_to :membership, Exhs.Organizations.Membership do
      allow_nil? false
    end
  end

  identities do
    identity :unique_stripe_subscription_id, [:stripe_subscription_id]
    identity :one_active_per_membership, [:membership_id]
  end
end
