defmodule Exhs.Organizations.Membership.Validations.NotLastAdmin do
  @moduledoc false
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, opts, _context) do
    membership = changeset.data
    tenant = membership.forening_id

    if should_check?(membership, changeset, opts) do
      other_admins =
        Exhs.Organizations.Membership
        |> Ash.Query.filter(role == :admin and id != ^membership.id)
        |> Ash.count!(tenant: tenant, authorize?: false)

      if other_admins == 0 do
        {:error, field: :role, message: opts[:message] || "cannot remove the last admin"}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp should_check?(membership, _changeset, on: :destroy) do
    membership.role == :admin
  end

  defp should_check?(membership, changeset, _opts) do
    membership.role == :admin and Ash.Changeset.get_attribute(changeset, :role) != :admin
  end
end
