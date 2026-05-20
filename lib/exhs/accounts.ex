defmodule Exhs.Accounts do
  @moduledoc false
  use Ash.Domain, otp_app: :exhs, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Exhs.Accounts.Token
    resource Exhs.Accounts.ApiKey

    resource Exhs.Accounts.User do
      define :register_with_password, args: [:email, :password, :password_confirmation]
      define :sign_in_with_password, args: [:email, :password]
      define :get_user_by_id, action: :get_by_id, args: [:id], get?: true
      define :get_user_by_email, action: :get_by_email, args: [:email], get?: true
      define :update_profile
      define :change_password
      define :request_password_reset_token, args: [:email]
      define :request_magic_link, args: [:email]
    end
  end
end
