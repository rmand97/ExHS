defmodule Exhs.Organizations.Forening do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "foreninger"
    repo Exhs.Repo
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :name,
        :slug,
        :subdomain,
        :branding,
        :kontingent_amount_cents,
        :kontingent_currency,
        :kontingent_stripe_price_id
      ]
    end

    update :update do
      accept [
        :name,
        :branding,
        :logo_url,
        :banner_url,
        :kontingent_amount_cents,
        :kontingent_currency,
        :kontingent_stripe_price_id
      ]
    end

    update :archive do
      accept []
      change set_attribute(:active, false)
    end

    update :set_stripe_account do
      accept [:stripe_account_id, :stripe_account_status]
    end

    read :get_by_id do
      get_by :id
    end

    read :get_by_slug do
      get_by :slug
    end

    read :get_by_subdomain do
      get_by :subdomain
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
      authorize_if actor_present()
    end

    policy action_type(:create) do
      forbid_if always()
    end

    policy action(:update) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action(:archive) do
      forbid_if always()
    end

    policy action(:set_stripe_account) do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :subdomain, :string do
      allow_nil? false
      public? true
    end

    attribute :branding, :map do
      public? true
      default %{}
    end

    attribute :logo_url, :string, public?: true
    attribute :banner_url, :string, public?: true

    attribute :kontingent_amount_cents, :integer, public?: true
    attribute :kontingent_currency, :string, public?: true, default: "DKK"
    attribute :kontingent_stripe_price_id, :string, public?: true

    attribute :stripe_account_id, :string, public?: true

    attribute :stripe_account_status, Exhs.Billing.Types.ConnectAccountStatus do
      public? true
      allow_nil? false
      default :none
    end

    attribute :active, :boolean do
      allow_nil? false
      default true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :memberships, Exhs.Organizations.Membership
  end

  identities do
    identity :unique_slug, [:slug]
    identity :unique_subdomain, [:subdomain]
  end
end
