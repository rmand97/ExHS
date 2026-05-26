defmodule Exhs.Audit.EventLog do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Audit,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

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
  end
end
