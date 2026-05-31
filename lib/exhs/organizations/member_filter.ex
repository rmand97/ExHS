defmodule Exhs.Organizations.MemberFilter do
  @moduledoc """
  In-memory filtering and sorting of loaded memberships for the admin members
  list. Shared by the `Members.Index` LiveView and the CSV export controller so
  both views apply identical rules. Each membership is expected to have `:user`
  and `:groups` loaded.

  Filters is a map with string values: `%{q:, status:, role:, group:, sort:}`.
  Blank values (`""` / `nil`) mean "no constraint".
  """

  def apply(memberships, filters) do
    memberships
    |> Enum.filter(&matches?(&1, filters))
    |> sort(filters[:sort])
  end

  defp matches?(m, f) do
    blank_or?(f[:status], &(to_string(m.status) == &1)) and
      blank_or?(f[:role], &(to_string(m.role) == &1)) and
      blank_or?(f[:group], fn id -> Enum.any?(m.groups, &(&1.id == id)) end) and
      blank_or?(f[:q], &query_match?(m, &1))
  end

  defp blank_or?(value, _fun) when value in [nil, ""], do: true
  defp blank_or?(value, fun), do: fun.(value)

  defp query_match?(m, q) do
    haystack =
      [m.user.email, m.user.first_name, m.user.last_name]
      |> Enum.map_join(" ", &to_string/1)
      |> String.downcase()

    String.contains?(haystack, String.downcase(q))
  end

  defp sort(members, "name"), do: Enum.sort_by(members, &name_key/1)
  defp sort(members, "joined_asc"), do: Enum.sort_by(members, & &1.joined_at, DateTime)
  defp sort(members, _joined_desc), do: Enum.sort_by(members, & &1.joined_at, {:desc, DateTime})

  defp name_key(m) do
    "#{m.user.first_name} #{m.user.last_name}" |> String.trim() |> String.downcase()
  end
end
