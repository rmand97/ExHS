defmodule Exhs.Events.TicketTypeGroup do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "event_ticket_type_groups"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
      reference :ticket_type, on_delete: :delete
      reference :group, on_delete: :delete
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read]

    create :add do
      primary? true
      accept [:ticket_type_id, :group_id]
      upsert? true
      upsert_identity :unique_ticket_type_group
    end

    destroy :remove do
      primary? true
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
      authorize_if actor_present()
    end

    policy action_type([:create, :destroy]) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end
  end

  multitenancy do
    strategy :attribute
    attribute :forening_id
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :forening, Exhs.Organizations.Forening do
      allow_nil? false
    end

    belongs_to :ticket_type, Exhs.Events.TicketType do
      allow_nil? false
      public? true
    end

    belongs_to :group, Exhs.Organizations.Group do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_ticket_type_group, [:ticket_type_id, :group_id]
  end
end
