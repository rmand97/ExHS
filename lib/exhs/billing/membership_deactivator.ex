defmodule Exhs.Billing.MembershipDeactivator do
  @moduledoc false
  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3

  alias Exhs.Billing.Subscription
  alias Exhs.Organizations
  alias Exhs.Organizations.Forening

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    foreninger = Ash.read!(Forening, authorize?: false)

    Enum.each(foreninger, fn forening ->
      deactivate_lapsed(forening)
    end)

    :ok
  end

  defp deactivate_lapsed(forening) do
    now = DateTime.utc_now()

    lapsed_subscriptions =
      Subscription
      |> Ash.Query.filter(
        status in [:canceled, :past_due] and
          not is_nil(current_period_end) and
          current_period_end < ^now
      )
      |> Ash.Query.load(:membership)
      |> Ash.read!(tenant: forening.id, authorize?: false)

    Enum.each(lapsed_subscriptions, fn sub ->
      if sub.membership.status == :active do
        Organizations.deactivate_member!(sub.membership,
          tenant: forening.id,
          authorize?: false
        )
      end
    end)
  end
end
