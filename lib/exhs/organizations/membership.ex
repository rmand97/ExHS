defmodule Exhs.Organizations.Membership do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "memberships"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read]

    create :invite do
      accept [:role]
      argument :user_id, :uuid, allow_nil?: false
      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:status, :active)
      change set_attribute(:joined_at, &DateTime.utc_now/0)
      change set_attribute(:activated_at, &DateTime.utc_now/0)
    end

    create :join do
      accept []
      change relate_actor(:user)
      change set_attribute(:role, :member)
      change set_attribute(:status, :active)
      change set_attribute(:joined_at, &DateTime.utc_now/0)
      change set_attribute(:activated_at, &DateTime.utc_now/0)
    end

    update :activate do
      accept []
      change set_attribute(:status, :active)
      change set_attribute(:activated_at, &DateTime.utc_now/0)
      change set_attribute(:deactivated_at, nil)
    end

    update :deactivate do
      accept []
      change set_attribute(:status, :inactive)
      change set_attribute(:deactivated_at, &DateTime.utc_now/0)
    end

    update :set_role do
      require_atomic? false
      accept [:role]
      validate Exhs.Organizations.Membership.Validations.NotLastAdmin
    end

    destroy :leave do
      require_atomic? false
      validate Exhs.Organizations.Membership.Validations.NotLastAdminDestroy
    end

    update :set_stripe_customer do
      accept [:stripe_customer_id]
    end

    read :my_memberships do
      multitenancy :allow_global
      filter expr(user_id == ^actor(:id))
      prepare build(sort: [joined_at: :desc], load: [:forening])
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass Exhs.Checks.Superadmin do
      authorize_if always()
    end

    policy action(:my_memberships) do
      authorize_if actor_present()
    end

    policy action(:join) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin, :board]}
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:invite) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action(:activate) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action(:deactivate) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action(:set_role) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action(:leave) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:set_stripe_customer) do
      forbid_if always()
    end
  end

  multitenancy do
    strategy :attribute
    attribute :forening_id
  end

  attributes do
    uuid_primary_key :id

    attribute :role, Exhs.Organizations.Types.MembershipRole do
      allow_nil? false
      default :member
      public? true
    end

    attribute :status, Exhs.Organizations.Types.MembershipStatus do
      allow_nil? false
      default :active
      public? true
    end

    attribute :joined_at, :utc_datetime_usec, public?: true
    attribute :activated_at, :utc_datetime_usec, public?: true
    attribute :deactivated_at, :utc_datetime_usec, public?: true

    attribute :stripe_customer_id, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Exhs.Accounts.User do
      allow_nil? false
    end

    belongs_to :forening, Exhs.Organizations.Forening do
      allow_nil? false
    end

    has_many :subscriptions, Exhs.Billing.Subscription
    has_many :registrations, Exhs.Events.Registration

    many_to_many :groups, Exhs.Organizations.Group do
      through Exhs.Organizations.MemberGroup
      source_attribute_on_join_resource :membership_id
      destination_attribute_on_join_resource :group_id
    end
  end

  identities do
    identity :unique_user_per_forening, [:user_id, :forening_id]
  end
end
