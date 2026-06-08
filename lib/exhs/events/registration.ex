defmodule Exhs.Events.Registration do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  alias Exhs.Events.WaitlistPromoter

  postgres do
    table "event_registrations"
    repo Exhs.Repo

    identity_wheres_to_sql one_per_ticket_type: "status != 'cancelled'"

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
      change Exhs.Events.Changes.BroadcastAvailability
    end

    # Paid-ticket cart entry: validated but not yet holding a seat (held_until nil).
    # The seat hold is taken later by `:hold` at checkout time.
    create :reserve do
      accept [:ticket_type_id, :membership_id]

      validate Exhs.Events.Validations.RegistrationAllowed

      change set_attribute(:registered_at, &DateTime.utc_now/0)
      change set_attribute(:status, :pending_payment)
    end

    # Take a timed seat hold for a pending_payment registration. Rejects (no
    # waitlist) when the ticket type is full — paid presale oversell is not allowed.
    update :hold do
      require_atomic? false
      argument :minutes, :integer, default: 10
      change Exhs.Events.Changes.HoldSeat
      change Exhs.Events.Changes.BroadcastAvailability
    end

    update :confirm do
      accept []
      change set_attribute(:status, :confirmed)
      change set_attribute(:held_until, nil)
      change Exhs.Events.Changes.BroadcastAvailability
    end

    update :release_hold do
      accept []
      change set_attribute(:status, :cancelled)
      change set_attribute(:held_until, nil)
      change set_attribute(:cancelled_at, &DateTime.utc_now/0)
      change Exhs.Events.Changes.BroadcastAvailability
    end

    update :cancel do
      accept []
      change set_attribute(:status, :cancelled)
      change set_attribute(:cancelled_at, &DateTime.utc_now/0)

      change after_action(fn _changeset, registration, _context ->
               %{ticket_type_id: registration.ticket_type_id, tenant: registration.forening_id}
               |> WaitlistPromoter.new()
               |> Oban.insert()

               {:ok, registration}
             end)
    end

    update :promote do
      accept []
      change set_attribute(:status, :confirmed)
      change Exhs.Events.Changes.BroadcastAvailability
    end

    read :get_by_id do
      get_by :id
    end

    read :for_event do
      argument :event_id, :uuid, allow_nil?: false
      filter expr(ticket_type.event_id == ^arg(:event_id))
      prepare build(sort: [registered_at: :desc], load: [:ticket_type, membership: [:user]])
    end

    read :my_registrations do
      multitenancy :bypass_all
      filter expr(membership.user_id == ^actor(:id))

      prepare build(
                sort: [registered_at: :desc],
                load: [ticket_type: [:event], membership: [:forening]]
              )
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

    policy action(:my_registrations) do
      authorize_if actor_present()
    end

    policy action([:register, :reserve]) do
      authorize_if expr(membership.user_id == ^actor(:id))
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action([:hold, :confirm, :release_hold]) do
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

    policy action(:promote) do
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
    attribute :held_until, :utc_datetime_usec, public?: true

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
    # Cancelled registrations free the slot so a member can re-buy after a dead order.
    identity :one_per_ticket_type, [:membership_id, :ticket_type_id],
      where: expr(status != :cancelled)
  end
end
