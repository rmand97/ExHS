defmodule Exhs.Checks.Superadmin do
  @moduledoc false
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is a superadmin"

  @impl true
  def match?(%{is_superadmin: true}, _context, _opts), do: true
  def match?(_, _, _), do: false
end
