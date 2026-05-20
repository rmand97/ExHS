defmodule Exhs.Checks.ActiveMember do
  @moduledoc false
  use Ash.Policy.SimpleCheck

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
        {:ok, membership} -> membership.status == :active
        _ -> false
      end
    end
  end

  defp get_tenant(%{subject: %{tenant: tenant}}) when tenant != nil, do: tenant
  defp get_tenant(%{changeset: %{tenant: tenant}}) when tenant != nil, do: tenant
  defp get_tenant(%{query: %{tenant: tenant}}) when tenant != nil, do: tenant
  defp get_tenant(_), do: nil

  defp lookup_membership(user_id, tenant) do
    require Ash.Query

    Exhs.Organizations.Membership
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.read_one(tenant: tenant, authorize?: false)
  end
end
