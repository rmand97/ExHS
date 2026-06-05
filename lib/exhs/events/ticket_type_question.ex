defmodule Exhs.Events.TicketTypeQuestion do
  @moduledoc false
  use Ash.Resource,
    otp_app: :exhs,
    domain: Exhs.Events,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "event_ticket_type_questions"
    repo Exhs.Repo

    references do
      reference :forening, on_delete: :delete
      reference :ticket_type, on_delete: :delete
    end
  end

  events do
    event_log Exhs.Audit.EventLog
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:ticket_type_id, :label, :field_type, :options, :required, :position]
    end

    update :update do
      accept [:label, :field_type, :options, :required, :position]
    end

    read :get_by_id do
      get_by :id
    end

    read :list_for_ticket_type do
      argument :ticket_type_id, :uuid, allow_nil?: false
      filter expr(ticket_type_id == ^arg(:ticket_type_id))
      prepare build(sort: [position: :asc])
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

    bypass action(:list_for_ticket_type) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if actor_present()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]}
    end
  end

  multitenancy do
    strategy :attribute
    attribute :forening_id
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      allow_nil? false
      public? true
    end

    attribute :field_type, Exhs.Events.Types.QuestionFieldType do
      allow_nil? false
      default :text
      public? true
    end

    attribute :options, {:array, :string} do
      public? true
      default []
    end

    attribute :required, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

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
  end
end
