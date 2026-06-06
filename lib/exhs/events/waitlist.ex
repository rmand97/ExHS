defmodule Exhs.Events.Waitlist do
  @moduledoc """
  Read helpers for a member's waitlist standing on a ticket type, for live
  display in the purchase UI. Position is 1-based and ordered by `registered_at`
  ascending — the same ordering `Exhs.Events.WaitlistPromoter` uses to pick the
  next member, so the displayed position predicts promotion order.

  All reads here run `authorize?: false`: these are trusted internal helpers
  called behind already-authorized actions and LiveViews. Do not call them with
  untrusted input.
  """
  alias Exhs.Events.Registration

  require Ash.Query

  @doc "The membership's `:waitlisted` registration for a ticket type, or nil."
  def entry(ticket_type_id, membership_id, tenant) do
    Registration
    |> Ash.Query.filter(
      ticket_type_id == ^ticket_type_id and membership_id == ^membership_id and
        status == :waitlisted
    )
    |> Ash.read_one!(tenant: tenant, authorize?: false)
  end

  @doc """
  A membership's live waitlist standing for a ticket type, or nil when the member
  is not waitlisted. `%{position: pos, total: count}` with `position` 1-based.
  """
  def standing(_ticket_type_id, nil, _tenant), do: nil

  def standing(ticket_type_id, membership_id, tenant) do
    case entry(ticket_type_id, membership_id, tenant) do
      nil ->
        nil

      registration ->
        %{position: position(registration, tenant), total: size(ticket_type_id, tenant)}
    end
  end

  @doc """
  1-based queue position for a waitlisted registration: the count of waitlisted
  entries for the same ticket type ordered at or before this one. Ordering is
  `(registered_at, id)` — identical to `Exhs.Events.WaitlistPromoter`, so the
  member at position 1 is exactly the next one promoted even when two
  registrations share a `registered_at`.
  """
  def position(%Registration{} = registration, tenant) do
    Registration
    |> Ash.Query.filter(
      ticket_type_id == ^registration.ticket_type_id and status == :waitlisted and
        (registered_at < ^registration.registered_at or
           (registered_at == ^registration.registered_at and id <= ^registration.id))
    )
    |> Ash.count!(tenant: tenant, authorize?: false)
  end

  @doc "Total `:waitlisted` registrations for a ticket type."
  def size(ticket_type_id, tenant) do
    Registration
    |> Ash.Query.filter(ticket_type_id == ^ticket_type_id and status == :waitlisted)
    |> Ash.count!(tenant: tenant, authorize?: false)
  end
end
