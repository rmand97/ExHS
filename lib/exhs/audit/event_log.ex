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
      filter expr(user_id == ^actor(:id))

      pagination offset?: true, default_limit: 25, countable: true

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
end
