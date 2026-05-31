defmodule Exhs.Audit.EventLog do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Audit,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "audit_events"
    repo Exhs.Repo
  end

  event_log do
    primary_key_type Ash.Type.UUIDv7

    persist_actor_primary_key :user_id, Exhs.Accounts.User
  end

  actions do
    defaults [:read]

    read :my_activity do
      argument :resource, :string

      filter expr(user_id == ^actor(:id))
      filter expr(is_nil(^arg(:resource)) or resource == ^arg(:resource))

      pagination offset?: true, default_limit: 25, countable: true

      prepare build(sort: [occurred_at: :desc])
    end

    read :for_record do
      argument :record_id, :uuid, allow_nil?: false
      filter expr(record_id == ^arg(:record_id))
      prepare build(sort: [occurred_at: :desc])
    end
  end

  policies do
    bypass Exhs.Checks.Superadmin do
      authorize_if always()
    end

    policy action(:my_activity) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:read) do
      authorize_if Exhs.Checks.Superadmin
    end
  end

  changes do
    change fn changeset, _context ->
      if changeset.tenant do
        Ash.Changeset.force_change_attribute(changeset, :forening_id, changeset.tenant)
      else
        changeset
      end
    end
  end

  attributes do
    attribute :forening_id, :uuid, public?: true
  end

  relationships do
    belongs_to :forening, Exhs.Organizations.Forening do
      define_attribute? false
      attribute_writable? true
    end
  end
end
