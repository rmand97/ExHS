defmodule Exhs.Accounts do
  use Ash.Domain, otp_app: :exhs, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Exhs.Accounts.Token
    resource Exhs.Accounts.User
  end
end
