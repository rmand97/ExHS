defmodule Exhs.Organizations.Types.MembershipRole do
  @moduledoc false
  use Ash.Type.Enum, values: [:admin, :board, :member]
end
