defmodule Exhs.Organizations.Group do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "groups"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :description, :color]
    end

    update :update do
      accept [:name, :description, :color]
    end

    destroy :destroy

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
      authorize_if {Exhs.Checks.ActiveMember, []}
    end

    policy action_type(:create) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action_type(:update) do
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

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string, public?: true

    attribute :color, :string do
      public? true
      constraints match: ~r/^#[0-9a-fA-F]{6}$/
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :forening, Exhs.Organizations.Forening do
      allow_nil? false
    end

    many_to_many :memberships, Exhs.Organizations.Membership do
      through Exhs.Organizations.MemberGroup
      source_attribute_on_join_resource :group_id
      destination_attribute_on_join_resource :membership_id
    end
  end

  identities do
    identity :unique_name_per_forening, [:name, :forening_id]
  end
end
