defmodule Exhs.Events do
  @moduledoc false
  use Ash.Domain, otp_app: :exhs, extensions: [AshAdmin.Domain]

  alias Exhs.Events.Checkout

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
      define :list_events, action: :read
      define :list_public_events, action: :list_public
      define :get_public_event, action: :get_public, args: [:id], get?: true
      define :list_member_events, action: :list_member_events, args: [:forening_ids]
      define :list_all_events, action: :all_global
    end

    resource Exhs.Events.TicketType do
      define :create_ticket_type, action: :create
      define :update_ticket_type, action: :update
      define :destroy_ticket_type, action: :destroy
      define :set_ticket_type_groups, action: :set_groups, args: [:group_ids]
      define :get_ticket_type_by_id, action: :get_by_id, args: [:id], get?: true
      define :list_ticket_types, action: :read
      define :list_ticket_types_for_event, action: :list_for_event, args: [:event_id]
    end

    resource Exhs.Events.TicketTypeQuestion do
      define :create_ticket_type_question, action: :create
      define :update_ticket_type_question, action: :update
      define :destroy_ticket_type_question, action: :destroy

      define :list_ticket_type_questions,
        action: :list_for_ticket_type,
        args: [:ticket_type_id]
    end

    resource Exhs.Events.TicketTypeGroup do
      define :add_ticket_type_group, action: :add
      define :list_ticket_type_groups, action: :read
    end

    resource Exhs.Events.AddOn do
      define :create_add_on, action: :create
      define :update_add_on, action: :update
      define :destroy_add_on, action: :destroy
      define :get_add_on_by_id, action: :get_by_id, args: [:id], get?: true
      define :list_add_ons, action: :read
      define :list_add_ons_for_event, action: :list_for_event, args: [:event_id]
    end

    resource Exhs.Events.Registration do
      define :register_for_event, action: :register
      define :reserve_registration, action: :reserve
      define :hold_registration, action: :hold
      define :confirm_registration, action: :confirm
      define :cancel_registration, action: :cancel
      define :promote_registration, action: :promote
      define :get_registration_by_id, action: :get_by_id, args: [:id], get?: true
      define :list_registrations, action: :read
      define :list_my_registrations, action: :my_registrations
    end

    resource Exhs.Events.Order do
      define :create_order, action: :create
      define :cancel_order, action: :cancel
      define :expire_order, action: :expire
      define :mark_order_paid, action: :mark_paid
      define :begin_order_checkout, action: :begin_checkout
      define :get_order, action: :get_by_id, args: [:id], get?: true

      define :get_order_by_session_id,
        action: :get_by_session_id,
        args: [:session_id],
        get?: true

      define :list_orders, action: :read
      define :list_orders_for_membership, action: :list_for_membership, args: [:membership_id]
      define :list_my_orders, action: :my_orders
    end

    resource Exhs.Events.OrderItem do
      define :add_order_item, action: :add
      define :remove_order_item, action: :remove
      define :get_order_item, action: :get_by_id, args: [:id], get?: true
      define :list_order_items, action: :list_for_order, args: [:order_id]
    end
  end

  @doc """
  Turn a `:building` order into a payment. Free orders confirm in place; paid
  orders take a seat hold and return a Stripe Checkout URL. See
  `Exhs.Events.Checkout`.
  """
  def checkout_order(order, opts), do: Checkout.checkout_order(order, opts)
end
