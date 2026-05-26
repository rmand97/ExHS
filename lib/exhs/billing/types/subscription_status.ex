defmodule Exhs.Billing.Types.SubscriptionStatus do
  @moduledoc false
  use Ash.Type.Enum, values: [:trialing, :active, :past_due, :canceled, :incomplete]
end
