defmodule Exhs.Organizations.Types.MembershipStatus do
  @moduledoc false
  use Ash.Type.Enum, values: [:active, :inactive]
end
