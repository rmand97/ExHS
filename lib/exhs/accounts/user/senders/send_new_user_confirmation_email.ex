defmodule Exhs.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends an email for a new user to confirm their email address.
  """

  use AshAuthentication.Sender
  use ExhsWeb, :verified_routes

  import Swoosh.Email

  alias Exhs.Mailer

  @impl true
  def send(user, token, _) do
    {name, address} = Application.fetch_env!(:exhs, Exhs.Mailer) |> Keyword.fetch!(:from)

    new()
    |> from({name, address})
    |> to(to_string(user.email))
    |> subject("Confirm your email address")
    |> html_body(body(token: token))
    |> Mailer.deliver!()
  end

  defp body(params) do
    url = url(~p"/confirm_new_user/#{params[:token]}")

    """
    <p>Click this link to confirm your email:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end
