defmodule Exhs.Events.OrderItem do
  @moduledoc """
  A single line in an order: either a `:ticket` (links/creates a Registration)
  or an `:addon` (links an AddOn). `unit_price_cents` is a snapshot taken at add
  time so later price changes never mutate an existing order. `responses` holds
  answers to the ticket type's custom questions, keyed by question id.
  """
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "event_order_items"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
      reference :order, on_delete: :delete
      reference :ticket_type, on_delete: :nilify
      reference :add_on, on_delete: :nilify
      reference :registration, on_delete: :nilify
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read]

    create :add do
      accept [:order_id, :item_type, :ticket_type_id, :add_on_id, :quantity, :responses]

      validate Exhs.Events.Validations.OrderBuildable
      validate Exhs.Events.Validations.OrderItemValid
      validate Exhs.Events.Validations.QuestionsAnswered

      change Exhs.Events.Changes.OrderItemSnapshot
      change Exhs.Events.Changes.CreateTicketRegistration
      change Exhs.Events.Changes.RecomputeOrderTotal
    end

    update :link_registration do
      accept [:registration_id]
    end

    destroy :remove do
      require_atomic? false
      change Exhs.Events.Changes.ReleaseItemRegistration
      change Exhs.Events.Changes.RecomputeOrderTotal
    end

    read :get_by_id do
      get_by :id
    end

    read :list_for_order do
      argument :order_id, :uuid, allow_nil?: false
      filter expr(order_id == ^arg(:order_id))
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

    policy action_type(:read) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin, :board]}
      authorize_if expr(order.membership.user_id == ^actor(:id))
    end

    policy action([:add, :remove]) do
      authorize_if expr(order.membership.user_id == ^actor(:id))
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end
  end

  multitenancy do
    strategy :attribute
    attribute :forening_id
  end

  attributes do
    uuid_primary_key :id

    attribute :item_type, Exhs.Events.Types.OrderItemType do
      allow_nil? false
      public? true
    end

    attribute :quantity, :integer do
      allow_nil? false
      default 1
      public? true
    end

    attribute :unit_price_cents, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :responses, :map do
      public? true
      default %{}
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :forening, Exhs.Organizations.Forening do
      allow_nil? false
    end

    belongs_to :order, Exhs.Events.Order do
      allow_nil? false
    end

    belongs_to :ticket_type, Exhs.Events.TicketType
    belongs_to :add_on, Exhs.Events.AddOn
    belongs_to :registration, Exhs.Events.Registration
  end
end
