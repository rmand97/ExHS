defmodule Exhs.Organizations.Membership.Validations.NotLastAdmin do
  @moduledoc false
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    membership = changeset.data
    tenant = membership.forening_id

    if membership.role == :admin && losing_admin_role?(changeset) do
      admin_count =
        Exhs.Organizations.Membership
        |> Ash.Query.filter(role == :admin and id != ^membership.id)
        |> Ash.read!(tenant: tenant, authorize?: false)
        |> length()

      if admin_count == 0 do
        {:error, field: :role, message: "cannot remove or demote the last admin"}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp losing_admin_role?(changeset) do
    case Ash.Changeset.get_attribute(changeset, :role) do
      :admin -> false
      _ -> true
    end
  end
end
