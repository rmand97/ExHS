defmodule Exhs.Events.Types.OrderStatus do
  @moduledoc false
  use Ash.Type.Enum, values: [:building, :pending_payment, :paid, :cancelled, :expired]
end
