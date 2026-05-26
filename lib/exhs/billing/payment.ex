defmodule Exhs.Billing.Payment do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "billing_payments"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read]

    create :record do
      accept [
        :payable_type,
        :payable_id,
        :amount_cents,
        :currency,
        :status,
        :stripe_payment_intent_id,
        :stripe_charge_id,
        :description,
        :paid_at
      ]
    end

    update :mark_refunded do
      accept []
      change set_attribute(:status, :refunded)
    end

    read :get_by_id do
      get_by :id
    end

    read :get_by_payment_intent do
      argument :stripe_payment_intent_id, :string, allow_nil?: false
      filter expr(stripe_payment_intent_id == ^arg(:stripe_payment_intent_id))
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
    end

    policy action_type(:create) do
      forbid_if always()
    end

    policy action(:mark_refunded) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end
  end

  multitenancy do
    strategy :attribute
    attribute :forening_id
  end

  attributes do
    uuid_primary_key :id

    attribute :payable_type, Exhs.Billing.Types.PayableType do
      allow_nil? false
      public? true
    end

    attribute :payable_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :amount_cents, :integer do
      allow_nil? false
      public? true
    end

    attribute :currency, :string do
      allow_nil? false
      default "DKK"
      public? true
    end

    attribute :status, Exhs.Billing.Types.PaymentStatus do
      allow_nil? false
      public? true
    end

    attribute :stripe_payment_intent_id, :string, public?: true
    attribute :stripe_charge_id, :string, public?: true
    attribute :description, :string, public?: true
    attribute :paid_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :forening, Exhs.Organizations.Forening do
      allow_nil? false
    end
  end

  identities do
    identity :unique_stripe_payment_intent_id, [:stripe_payment_intent_id]
  end
end
