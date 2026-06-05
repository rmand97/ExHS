defmodule Exhs.Events.Order do
  @moduledoc """
  An order is the cart/purchase aggregate. It groups one or more `OrderItem`s
  (tickets and add-ons), carries the running `total_cents`, and owns the seat
  hold (`held_until`) and Stripe checkout session for paid flows. One `Payment`
  per order links back via `payable_type: :order`.
  """
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "event_orders"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
      reference :membership, on_delete: :delete
      reference :event, on_delete: :delete
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read]

    create :create do
      accept [:event_id, :membership_id]
      change set_attribute(:status, :building)
      change set_attribute(:total_cents, 0)
    end

    update :set_total do
      accept [:total_cents]
    end

    update :begin_checkout do
      accept [:stripe_checkout_session_id, :held_until]
      change set_attribute(:status, :pending_payment)
    end

    update :mark_paid do
      require_atomic? false
      change set_attribute(:status, :paid)
      change set_attribute(:paid_at, &DateTime.utc_now/0)
      change set_attribute(:held_until, nil)
      change Exhs.Events.Changes.ConfirmOrderRegistrations
    end

    update :cancel do
      require_atomic? false
      change set_attribute(:status, :cancelled)
      change Exhs.Events.Changes.ReleaseOrderHolds
    end

    update :expire do
      require_atomic? false
      validate attribute_does_not_equal(:status, :paid)
      change set_attribute(:status, :expired)
      change Exhs.Events.Changes.ReleaseOrderHolds
    end

    read :get_by_id do
      get_by :id
      prepare build(load: [:items, :payment])
    end

    read :get_by_session_id do
      argument :session_id, :string, allow_nil?: false
      filter expr(stripe_checkout_session_id == ^arg(:session_id))
      get? true
    end

    read :list_for_membership do
      argument :membership_id, :uuid, allow_nil?: false
      filter expr(membership_id == ^arg(:membership_id))
      prepare build(sort: [inserted_at: :desc], load: [:items])
    end

    read :my_orders do
      multitenancy :bypass_all
      filter expr(membership.user_id == ^actor(:id))
      prepare build(sort: [inserted_at: :desc], load: [:items, :event])
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    bypass Exhs.Checks.Superadmin do
      authorize_if always()
    end

    policy action(:my_orders) do
      authorize_if actor_present()
    end

    policy action(:create) do
      authorize_if expr(membership.user_id == ^actor(:id))
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action_type(:read) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin, :board]}
      authorize_if expr(membership.user_id == ^actor(:id))
    end

    policy action_type(:update) do
      authorize_if expr(membership.user_id == ^actor(:id))
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end
  end

  multitenancy do
    strategy :attribute
    attribute :forening_id
  end

  attributes do
    uuid_primary_key :id

    attribute :status, Exhs.Events.Types.OrderStatus do
      allow_nil? false
      default :building
      public? true
    end

    attribute :total_cents, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :currency, :string do
      allow_nil? false
      default "DKK"
      public? true
    end

    attribute :held_until, :utc_datetime_usec, public?: true
    attribute :stripe_checkout_session_id, :string, public?: true
    attribute :paid_at, :utc_datetime_usec, public?: true

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

    belongs_to :event, Exhs.Events.Event do
      allow_nil? false
    end

    has_many :items, Exhs.Events.OrderItem

    has_one :payment, Exhs.Billing.Payment do
      no_attributes? true
      filter expr(payable_type == :order and payable_id == parent(id))
    end
  end
end
