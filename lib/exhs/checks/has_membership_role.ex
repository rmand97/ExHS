defmodule Exhs.Checks.HasMembershipRole do
  @moduledoc false
  use Ash.Policy.SimpleCheck

  import Exhs.Checks.Helpers, only: [get_tenant: 1, lookup_membership: 2]

  @impl true
  def describe(opts) do
    roles = Keyword.get(opts, :roles, [:admin])
    "actor has membership with role in #{inspect(roles)}"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, context, opts) do
    roles = Keyword.get(opts, :roles, [:admin])
    tenant = get_tenant(context)

    if is_nil(tenant) do
      false
    else
      case lookup_membership(actor.id, tenant) do
        {:ok, %{role: role}} -> role in roles
        _ -> false
      end
    end
  end
end
