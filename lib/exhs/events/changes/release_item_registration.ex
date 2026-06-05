defmodule Exhs.Events.Changes.ReleaseItemRegistration do
  @moduledoc "Cancels the linked Registration when a ticket item is removed from a cart."
  use Ash.Resource.Change

  alias Ash.Changeset

  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, fn changeset ->
      release(changeset.data.registration_id, changeset.tenant)
      changeset
    end)
  end

  defp release(nil, _tenant), do: :ok

  defp release(registration_id, tenant) do
    case Ash.get(Exhs.Events.Registration, registration_id, tenant: tenant, authorize?: false) do
      {:ok, registration} ->
        registration
        |> Changeset.for_update(:release_hold, %{}, tenant: tenant, authorize?: false)
        |> Ash.update!()

      _ ->
        :ok
    end
  end
end
