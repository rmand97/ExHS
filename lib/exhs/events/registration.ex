defmodule Exhs.Events.Registration do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "event_registrations"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
      reference :ticket_type, on_delete: :delete
      reference :membership, on_delete: :delete
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read]

    create :register do
      accept [:ticket_type_id, :membership_id]

      validate Exhs.Events.Validations.RegistrationAllowed

      change set_attribute(:registered_at, &DateTime.utc_now/0)
      change Exhs.Events.Changes.CheckCapacity
    end

    update :cancel do
      accept []
      change set_attribute(:status, :cancelled)
      change set_attribute(:cancelled_at, &DateTime.utc_now/0)
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

    policy action(:register) do
      authorize_if expr(membership.user_id == ^actor(:id))
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action_type(:read) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin, :board]}
      authorize_if expr(membership.user_id == ^actor(:id))
    end

    policy action(:cancel) do
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

    attribute :status, Exhs.Events.Types.RegistrationStatus do
      allow_nil? false
      public? true
    end

    attribute :registered_at, :utc_datetime_usec, public?: true
    attribute :cancelled_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :forening, Exhs.Organizations.Forening do
      allow_nil? false
    end

    belongs_to :ticket_type, Exhs.Events.TicketType do
      allow_nil? false
    end

    belongs_to :membership, Exhs.Organizations.Membership do
      allow_nil? false
    end
  end

  identities do
    identity :one_per_ticket_type, [:membership_id, :ticket_type_id]
  end
end
