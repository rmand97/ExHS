defmodule Exhs.Organizations.Forening do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "foreninger"
    repo Exhs.Repo
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
        :kontingent_amount_cents,
        :kontingent_currency,
        :kontingent_stripe_price_id
      ]
    end

    update :archive do
      accept []
      change set_attribute(:active, false)
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

    attribute :kontingent_amount_cents, :integer, public?: true
    attribute :kontingent_currency, :string, public?: true, default: "DKK"
    attribute :kontingent_stripe_price_id, :string, public?: true

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
