defmodule Exhs.Billing.Types.ConnectAccountStatus do
  @moduledoc false
  use Ash.Type.Enum, values: [:none, :onboarding, :active, :restricted]
end
