defmodule Exhs.Events.Types.OrderItemType do
  @moduledoc false
  use Ash.Type.Enum, values: [:ticket, :addon]
end
