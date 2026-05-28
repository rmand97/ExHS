defmodule Exhs.Billing.Preparations.FilterByActorMemberships do
  @moduledoc false
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, %{actor: %{id: _} = actor}) do
    require Ash.Query

    membership_ids =
      case Exhs.Organizations.list_my_memberships(actor: actor) do
        {:ok, memberships} -> Enum.map(memberships, & &1.id)
        _ -> []
      end

    Ash.Query.filter(query, payable_id in ^membership_ids)
  end
end
