defmodule Exhs.Organizations.MemberGroup do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "member_groups"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
      reference :membership, on_delete: :delete
      reference :group, on_delete: :delete
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read]

    create :add do
      accept [:membership_id, :group_id]
      upsert? true
      upsert_identity :unique_member_group
    end

    destroy :remove
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass Exhs.Checks.Superadmin do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if {Exhs.Checks.ActiveMember, []}
    end

    policy action_type(:create) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action_type(:destroy) do
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

    belongs_to :membership, Exhs.Organizations.Membership do
      allow_nil? false
      public? true
    end

    belongs_to :group, Exhs.Organizations.Group do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_member_group, [:membership_id, :group_id, :forening_id]
  end
end
