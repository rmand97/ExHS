defmodule Exhs.Checks.HasMembershipRole do
  @moduledoc false
  use Ash.Policy.FilterCheck

  @impl true
  def describe(opts) do
    roles = Keyword.get(opts, :roles, [:admin])
    "actor has membership with role in #{inspect(roles)}"
  end

  @impl true
  def filter(_actor, context, opts) do
    roles = Keyword.get(opts, :roles, [:admin])
    path = membership_path(context.resource)

    expr(exists(^path, user_id == ^actor(:id) and role in ^roles))
  end

  defp membership_path(Exhs.Organizations.Forening), do: [:memberships]
  defp membership_path(_resource), do: [:forening, :memberships]
end
