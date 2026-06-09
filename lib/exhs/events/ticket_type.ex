defmodule Exhs.Events.TicketType do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "event_ticket_types"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
      reference :event, on_delete: :delete
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :event_id,
        :name,
        :price_cents,
        :currency,
        :capacity,
        :description,
        :sales_starts_at,
        :sales_ends_at,
        :allow_multiple
      ]

      validate attribute_equals(:currency, "DKK"), message: "only DKK is supported"
    end

    update :update do
      accept [
        :name,
        :price_cents,
        :currency,
        :capacity,
        :description,
        :sales_starts_at,
        :sales_ends_at,
        :allow_multiple
      ]

      validate attribute_equals(:currency, "DKK"), message: "only DKK is supported"
    end

    update :set_groups do
      require_atomic? false
      argument :group_ids, {:array, :uuid}, allow_nil?: false
      change manage_relationship(:group_ids, :eligible_groups, type: :append_and_remove)
    end

    read :get_by_id do
      get_by :id
    end

    read :list_for_event do
      argument :event_id, :uuid, allow_nil?: false
      filter expr(event_id == ^arg(:event_id))
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass Exhs.Checks.Superadmin do
      authorize_if always()
    end

    bypass action(:list_for_event) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if actor_present()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end
  end

  multitenancy do
    strategy :attribute
    attribute :forening_id
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :price_cents, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :currency, :string do
      allow_nil? false
      default "DKK"
      public? true
    end

    attribute :capacity, :integer, public?: true

    attribute :description, :string, public?: true

    attribute :sales_starts_at, :utc_datetime_usec, public?: true
    attribute :sales_ends_at, :utc_datetime_usec, public?: true

    attribute :allow_multiple, :boolean do
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

    belongs_to :event, Exhs.Events.Event do
      allow_nil? false
    end

    has_many :registrations, Exhs.Events.Registration
    has_many :questions, Exhs.Events.TicketTypeQuestion

    many_to_many :eligible_groups, Exhs.Organizations.Group do
      through Exhs.Events.TicketTypeGroup
      source_attribute_on_join_resource :ticket_type_id
      destination_attribute_on_join_resource :group_id
    end
  end

  calculations do
    calculate :seats_left,
              :integer,
              expr(if is_nil(capacity), do: nil, else: capacity - seats_taken)
  end

  aggregates do
    count :seats_taken, :registrations do
      filter expr(status == :confirmed or (status == :pending_payment and held_until > now()))
    end
  end

  identities do
    identity :unique_name_per_event, [:name, :event_id]
  end
end
