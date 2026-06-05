defmodule Exhs.Events.Validations.OrderBuildable do
  @moduledoc "Only orders still in `:building` may have items added."
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    order_id = Ash.Changeset.get_attribute(changeset, :order_id)
    tenant = changeset.tenant

    case Ash.get(Exhs.Events.Order, order_id, tenant: tenant, authorize?: false) do
      {:ok, %{status: :building}} ->
        :ok

      {:ok, _other} ->
        {:error, field: :order_id, message: "order is no longer open for changes"}

      _ ->
        {:error, field: :order_id, message: "order not found"}
    end
  end
end
