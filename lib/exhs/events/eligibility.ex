defmodule Exhs.Events.Eligibility do
  @moduledoc """
  Computes a ticket type's purchasability for a given membership, for display in
  the purchase UI. The authoritative enforcement lives in
  `Exhs.Events.Validations.RegistrationAllowed`; this mirrors it for badges and
  disabled states. Returns one of `:available`, `:not_open`, `:closed`,
  `:ineligible`, `:sold_out`.
  """
  alias Exhs.Events

  require Ash.Query

  def status(ticket_type, event, membership, tenant) do
    cond do
      not within_window?(ticket_type, event) -> window_state(ticket_type, event)
      not eligible?(ticket_type, membership, tenant) -> :ineligible
      sold_out?(ticket_type, tenant) -> :sold_out
      true -> :available
    end
  end

  @doc "True when the ticket type is restricted to one or more groups."
  def gated?(ticket_type, tenant) do
    eligible_group_ids(ticket_type.id, tenant) != []
  end

  defp window_state(ticket_type, event) do
    now = DateTime.utc_now()
    opens = ticket_type.sales_starts_at || event.registration_opens_at

    if opens && DateTime.compare(now, opens) == :lt, do: :not_open, else: :closed
  end

  defp within_window?(ticket_type, event) do
    now = DateTime.utc_now()
    opens = ticket_type.sales_starts_at || event.registration_opens_at
    closes = ticket_type.sales_ends_at || event.registration_closes_at

    before_open? = opens && DateTime.compare(now, opens) == :lt
    after_close? = closes && DateTime.compare(now, closes) == :gt

    !before_open? and !after_close?
  end

  @doc "True when `membership` may buy `ticket_type` given its group gating."
  def eligible?(ticket_type, membership, tenant) do
    group_ids = eligible_group_ids(ticket_type.id, tenant)
    group_ids == [] or (membership && member_in_any_group?(membership.id, group_ids, tenant))
  end

  @doc "Group ids a ticket type is gated to (empty when ungated)."
  def eligible_group_ids(ticket_type_id, tenant) do
    Events.TicketTypeGroup
    |> Ash.Query.filter(ticket_type_id == ^ticket_type_id)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.map(& &1.group_id)
  end

  @doc "True when the membership belongs to any of the given groups."
  def member_in_any_group?(membership_id, group_ids, tenant) do
    Exhs.Organizations.MemberGroup
    |> Ash.Query.filter(membership_id == ^membership_id and group_id in ^group_ids)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.any?()
  end

  defp sold_out?(%{capacity: nil}, _tenant), do: false

  defp sold_out?(%{capacity: cap, id: id}, tenant),
    do: Events.Capacity.seats_taken(id, tenant) >= cap
end
