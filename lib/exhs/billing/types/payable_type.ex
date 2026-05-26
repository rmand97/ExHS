defmodule Exhs.Billing.Types.PayableType do
  @moduledoc false
  use Ash.Type.Enum, values: [:subscription, :registration, :order]
end
