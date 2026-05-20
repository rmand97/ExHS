defmodule Exhs.Checks.ActiveMember do
  @moduledoc false
  use Ash.Policy.SimpleCheck

  import Exhs.Checks.Helpers, only: [get_tenant: 1, lookup_membership: 2]

  @impl true
  def describe(_opts), do: "actor has an active membership in the current tenant"

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, context, _opts) do
    tenant = get_tenant(context)

    if is_nil(tenant) do
      false
    else
      case lookup_membership(actor.id, tenant) do
        {:ok, %{status: status}} -> status == :active
        _ -> false
      end
    end
  end
end
