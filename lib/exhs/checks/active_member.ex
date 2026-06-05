defmodule Exhs.Checks.ActiveMember do
  @moduledoc false
  use Ash.Policy.FilterCheck

  @impl true
  def describe(_opts), do: "actor has an active membership in the current tenant"

  @impl true
  def filter(_actor, context, _opts) do
    path = membership_path(context.resource)

    expr(exists(^path, user_id == ^actor(:id) and status == :active))
  end

  defp membership_path(Exhs.Organizations.Forening), do: [:memberships]
  defp membership_path(_resource), do: [:forening, :memberships]
end
