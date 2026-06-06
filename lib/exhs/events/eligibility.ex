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

  def status(ticket_type, event, membership, tenant),
    do: status(ticket_type, event, membership, tenant, eligible_group_ids(ticket_type.id, tenant))

  @doc """
  Same as `status/4` but with the ticket type's gating group ids supplied by the
  caller, so a UI rendering many tickets fetches them once instead of per call.
  """
  def status(ticket_type, event, membership, tenant, group_ids) do
    cond do
      not within_window?(ticket_type, event) -> window_state(ticket_type, event)
      not eligible_for_groups?(group_ids, membership, tenant) -> :ineligible
      sold_out?(ticket_type, tenant) -> :sold_out
      true -> :available
    end
  end

  defp eligible_for_groups?([], _membership, _tenant), do: true
  defp eligible_for_groups?(_group_ids, nil, _tenant), do: false

  defp eligible_for_groups?(group_ids, membership, tenant),
    do: member_in_any_group?(membership.id, group_ids, tenant)

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
