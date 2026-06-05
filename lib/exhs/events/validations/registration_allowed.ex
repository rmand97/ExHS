defmodule Exhs.Events.Validations.RegistrationAllowed do
  @moduledoc false
  use Ash.Resource.Validation

  alias Exhs.Events.Eligibility

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    ticket_type_id = Ash.Changeset.get_attribute(changeset, :ticket_type_id)
    membership_id = Ash.Changeset.get_attribute(changeset, :membership_id)
    tenant = changeset.tenant

    with {:ok, ticket_type} <- load_ticket_type(ticket_type_id, tenant),
         {:ok, event} <- load_event(ticket_type.event_id, tenant),
         :ok <- check_published(event),
         :ok <- check_sales_window(ticket_type, event),
         {:ok, membership} <- load_membership(membership_id, tenant),
         :ok <- check_membership(event, membership) do
      check_group_eligibility(ticket_type, membership_id, tenant)
    end
  end

  defp load_ticket_type(id, tenant) do
    case Ash.get(Exhs.Events.TicketType, id, tenant: tenant, authorize?: false) do
      {:ok, tt} -> {:ok, tt}
      _ -> {:error, field: :ticket_type_id, message: "ticket type not found"}
    end
  end

  defp load_event(id, tenant) do
    case Ash.get(Exhs.Events.Event, id, tenant: tenant, authorize?: false) do
      {:ok, event} -> {:ok, event}
      _ -> {:error, field: :ticket_type_id, message: "event not found"}
    end
  end

  defp load_membership(id, tenant) do
    case Ash.get(Exhs.Organizations.Membership, id, tenant: tenant, authorize?: false) do
      {:ok, m} -> {:ok, m}
      _ -> {:error, field: :membership_id, message: "membership not found"}
    end
  end

  defp check_published(%{published: true}), do: :ok
  defp check_published(_), do: {:error, field: :ticket_type_id, message: "event is not published"}

  # Ticket-type sales window takes precedence; a nil bound falls back to the
  # event's registration window.
  defp check_sales_window(ticket_type, event) do
    now = DateTime.utc_now()
    opens = ticket_type.sales_starts_at || event.registration_opens_at
    closes = ticket_type.sales_ends_at || event.registration_closes_at

    cond do
      opens && DateTime.compare(now, opens) == :lt ->
        {:error, field: :ticket_type_id, message: "sales have not opened yet"}

      closes && DateTime.compare(now, closes) == :gt ->
        {:error, field: :ticket_type_id, message: "sales have closed"}

      true ->
        :ok
    end
  end

  defp check_membership(%{membership_required: false}, _membership), do: :ok
  defp check_membership(%{membership_required: true}, %{status: :active}), do: :ok

  defp check_membership(%{membership_required: true}, _),
    do: {:error, field: :membership_id, message: "active membership required"}

  defp check_group_eligibility(ticket_type, membership_id, tenant) do
    group_ids = Eligibility.eligible_group_ids(ticket_type.id, tenant)

    cond do
      group_ids == [] ->
        :ok

      Eligibility.member_in_any_group?(membership_id, group_ids, tenant) ->
        :ok

      true ->
        {:error, field: :ticket_type_id, message: "this ticket is restricted to eligible groups"}
    end
  end
end
