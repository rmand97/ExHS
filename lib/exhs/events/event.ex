defmodule Exhs.Events.Event do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "events"
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
      accept [
        :title,
        :description,
        :location,
        :starts_at,
        :ends_at,
        :cover_image_url,
        :registration_opens_at,
        :registration_closes_at,
        :membership_required
      ]
    end

    update :update do
      accept [
        :title,
        :description,
        :location,
        :starts_at,
        :ends_at,
        :cover_image_url,
        :registration_opens_at,
        :registration_closes_at,
        :membership_required
      ]
    end

    update :publish do
      accept []
      change set_attribute(:published, true)
    end

    update :unpublish do
      accept []
      change set_attribute(:published, false)
    end

    read :get_by_id do
      get_by :id
    end

    read :list_public do
      prepare build(filter: [published: true], sort: [starts_at: :asc])
      filter expr(starts_at > now())
    end

    read :list_member_events do
      multitenancy :bypass_all

      argument :forening_ids, {:array, :uuid}, allow_nil?: false

      filter expr(forening_id in ^arg(:forening_ids) and published == true and starts_at > now())
      prepare build(sort: [starts_at: :asc], load: [:forening])
    end

    read :get_public do
      get_by :id
      filter expr(published == true)
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass Exhs.Checks.Superadmin do
      authorize_if always()
    end

    policy action(:list_member_events) do
      authorize_if actor_present()
    end

    bypass action([:list_public, :get_public]) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin, :board]}
      authorize_if expr(published == true)
    end

    policy action_type(:create) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end

    policy action_type(:update) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end
  end

  multitenancy do
    strategy :attribute
    attribute :forening_id
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string, public?: true
    attribute :location, :string, public?: true

    attribute :starts_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :ends_at, :utc_datetime_usec, public?: true

    attribute :published, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :membership_required, :boolean do
      allow_nil? false
      default true
      public? true
    end

    attribute :cover_image_url, :string, public?: true
    attribute :registration_opens_at, :utc_datetime_usec, public?: true
    attribute :registration_closes_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :forening, Exhs.Organizations.Forening do
      allow_nil? false
    end

    has_many :ticket_types, Exhs.Events.TicketType
  end
end
