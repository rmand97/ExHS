defmodule Exhs.Audit do
  @moduledoc false
  use Ash.Domain, otp_app: :exhs, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Exhs.Audit.EventLog do
      define :list_my_activity, action: :my_activity
      define :list_events_for_record, action: :for_record, args: [:record_id]
    end
  end
end
