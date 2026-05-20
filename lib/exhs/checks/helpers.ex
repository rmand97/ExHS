defmodule Exhs.Checks.Helpers do
  @moduledoc false

  def get_tenant(%{subject: %{tenant: tenant}}) when tenant != nil, do: tenant
  def get_tenant(%{changeset: %{tenant: tenant}}) when tenant != nil, do: tenant
  def get_tenant(%{query: %{tenant: tenant}}) when tenant != nil, do: tenant
  def get_tenant(_), do: nil

  def lookup_membership(user_id, tenant) do
    require Ash.Query

    Exhs.Organizations.Membership
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.read_one(tenant: tenant, authorize?: false)
  end
end
