defmodule Exhs.Scope do
  @moduledoc false
  defstruct [:actor, :tenant]

  defimpl Ash.Scope.ToOpts do
    def get_actor(%{actor: actor}), do: {:ok, actor}
    def get_tenant(%{tenant: tenant}), do: {:ok, tenant}
    def get_context(_), do: :error
    def get_tracer(_), do: :error
    def get_authorize?(_), do: :error
  end
end
