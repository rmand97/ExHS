defmodule Exhs.Events do
  @moduledoc false
  use Ash.Domain, otp_app: :exhs, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Exhs.Events.Event do
      define :create_event, action: :create
      define :update_event, action: :update
      define :publish_event, action: :publish
      define :unpublish_event, action: :unpublish
      define :get_event_by_id, action: :get_by_id, args: [:id], get?: true
      define :list_upcoming_events, action: :list_upcoming
      define :list_events, action: :read
      define :list_public_events, action: :list_public
      define :get_public_event, action: :get_public, args: [:id], get?: true
      define :list_member_events, action: :list_member_events, args: [:forening_ids]
    end

    resource Exhs.Events.TicketType do
      define :create_ticket_type, action: :create
      define :update_ticket_type, action: :update
      define :destroy_ticket_type, action: :destroy
      define :get_ticket_type_by_id, action: :get_by_id, args: [:id], get?: true
      define :list_ticket_types, action: :read
      define :list_ticket_types_for_event, action: :list_for_event, args: [:event_id]
    end

    resource Exhs.Events.Registration do
      define :register_for_event, action: :register
      define :cancel_registration, action: :cancel
      define :promote_registration, action: :promote
      define :get_registration_by_id, action: :get_by_id, args: [:id], get?: true
      define :list_registrations, action: :read
      define :list_my_registrations, action: :my_registrations
    end
  end
end
