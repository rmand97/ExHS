defmodule Exhs.Organizations.InviteWorker do
  @moduledoc """
  Sends the magic-link sign-in email to a freshly invited member. Runs on the
  `mailers` queue so the inviting admin's request returns immediately and email
  delivery is retried independently of the web request.
  """
  use Oban.Worker, queue: :mailers, max_attempts: 5

  def enqueue(email) when is_binary(email) do
    %{email: email}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email" => email}}) do
    Exhs.Accounts.request_magic_link(email)
  end
end
