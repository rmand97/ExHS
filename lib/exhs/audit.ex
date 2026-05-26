defmodule Exhs.Audit do
  @moduledoc false
  use Ash.Domain, otp_app: :exhs, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Exhs.Audit.EventLog
  end
end
