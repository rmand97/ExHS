defmodule Exhs.Events.WaitlistPromoter do
  @moduledoc false
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 30, keys: [:ticket_type_id, :tenant]]

  alias Ash.Query
  alias Exhs.Events.Registration

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ticket_type_id" => ticket_type_id, "tenant" => tenant}}) do
    case next_waitlisted(ticket_type_id, tenant) do
      nil -> :ok
      registration -> promote(registration, tenant)
    end
  end

  defp next_waitlisted(ticket_type_id, tenant) do
    Registration
    |> Query.filter(ticket_type_id == ^ticket_type_id and status == :waitlisted)
    |> Query.sort(registered_at: :asc)
    |> Query.limit(1)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> List.first()
  end

  defp promote(registration, tenant) do
    Exhs.Events.promote_registration(registration, tenant: tenant, authorize?: false)
    :ok
  end
end
