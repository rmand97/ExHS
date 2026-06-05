defmodule Exhs.Events.Changes.ReleaseOrderHolds do
  @moduledoc """
  On order cancel/expire, releases the seat hold of every linked ticket
  Registration and enqueues a `WaitlistPromoter` for each affected ticket type.
  Already-cancelled registrations are skipped, so the change is idempotent.
  """
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Exhs.Events.{OrderItems, WaitlistPromoter}

  def change(changeset, _opts, _context) do
    Changeset.after_action(changeset, fn changeset, order ->
      tenant = changeset.tenant

      order.id
      |> OrderItems.ticket_registrations(tenant)
      |> Enum.reject(&(&1.status == :cancelled))
      |> Enum.each(fn registration ->
        Ash.update!(
          Changeset.for_update(registration, :release_hold, %{},
            tenant: tenant,
            authorize?: false
          )
        )

        enqueue_promotion(registration.ticket_type_id, tenant)
      end)

      {:ok, order}
    end)
  end

  defp enqueue_promotion(ticket_type_id, tenant) do
    %{ticket_type_id: ticket_type_id, tenant: tenant}
    |> WaitlistPromoter.new()
    |> Oban.insert()
  end
end
