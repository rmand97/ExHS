defmodule Exhs.Events.Validations.RegistrationAllowed do
  @moduledoc false
  use Ash.Resource.Validation

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
         :ok <- check_registration_window(event),
         {:ok, membership} <- load_membership(membership_id, tenant) do
      check_membership(event, membership)
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

  defp check_registration_window(event) do
    now = DateTime.utc_now()

    cond do
      event.registration_opens_at && DateTime.compare(now, event.registration_opens_at) == :lt ->
        {:error, field: :ticket_type_id, message: "registration has not opened yet"}

      event.registration_closes_at && DateTime.compare(now, event.registration_closes_at) == :gt ->
        {:error, field: :ticket_type_id, message: "registration has closed"}

      true ->
        :ok
    end
  end

  defp check_membership(%{membership_required: false}, _membership), do: :ok
  defp check_membership(%{membership_required: true}, %{status: :active}), do: :ok

  defp check_membership(%{membership_required: true}, _),
    do: {:error, field: :membership_id, message: "active membership required"}
end
