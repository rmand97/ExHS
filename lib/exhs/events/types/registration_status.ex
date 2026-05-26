defmodule Exhs.Events.Types.RegistrationStatus do
  @moduledoc false
  use Ash.Type.Enum, values: [:confirmed, :waitlisted, :cancelled, :pending_payment]
end
