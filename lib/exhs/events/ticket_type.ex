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
      accept [:event_id, :name, :price_cents, :currency, :capacity, :description]
    end

    update :update do
      accept [:name, :price_cents, :currency, :capacity, :description]
    end

    read :get_by_id do
      get_by :id
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
  end

  identities do
    identity :unique_name_per_event, [:name, :event_id]
  end
end
