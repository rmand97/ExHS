defmodule Exhs.Organizations.Membership.Validations.NotLastAdminDestroy do
  @moduledoc false
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    membership = changeset.data
    tenant = membership.forening_id

    if membership.role == :admin do
      admin_count =
        Exhs.Organizations.Membership
        |> Ash.Query.filter(role == :admin and id != ^membership.id)
        |> Ash.read!(tenant: tenant, authorize?: false)
        |> length()

      if admin_count == 0 do
        {:error, field: :role, message: "cannot remove the last admin"}
      else
        :ok
      end
    else
      :ok
    end
  end
end
