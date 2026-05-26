defmodule Exhs.Billing.Types.PaymentStatus do
  @moduledoc false
  use Ash.Type.Enum, values: [:pending, :succeeded, :failed, :refunded]
end
