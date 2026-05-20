defmodule Exhs.Organizations.Membership do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "memberships"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
      reference :user, on_delete: :delete
    end
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
      accept [:role]
    end

    destroy :leave
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
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
  end

  identities do
    identity :unique_user_per_forening, [:user_id, :forening_id]
  end
end
