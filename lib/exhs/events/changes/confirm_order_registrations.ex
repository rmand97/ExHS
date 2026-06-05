defmodule Exhs.Events.Changes.ConfirmOrderRegistrations do
  @moduledoc "On order payment, confirms every linked ticket Registration and clears holds."
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Exhs.Events.OrderItems

  def change(changeset, _opts, _context) do
    Changeset.after_action(changeset, fn changeset, order ->
      tenant = changeset.tenant

      order.id
      |> OrderItems.ticket_registrations(tenant)
      |> Enum.each(fn registration ->
        Ash.update!(
          Changeset.for_update(registration, :confirm, %{}, tenant: tenant, authorize?: false)
        )
      end)

      {:ok, order}
    end)
  end
end
