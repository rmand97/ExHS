defmodule Exhs.Billing.WebhookWorkerTest do
  use Exhs.DataCase, async: true

  alias Exhs.Billing.WebhookWorker

  describe "perform/1" do
    test "dispatches event to Webhook.apply_event" do
      event = %{
        "type" => "checkout.session.completed",
        "id" => "evt_test_#{System.unique_integer([:positive])}"
      }

      job = %Oban.Job{args: %{"event" => event}}
      assert :ok = WebhookWorker.perform(job)
    end

    test "unknown event type returns ok (no crash)" do
      event = %{
        "type" => "unknown.event.type",
        "id" => "evt_unknown_#{System.unique_integer([:positive])}"
      }

      job = %Oban.Job{args: %{"event" => event}}
      assert :ok = WebhookWorker.perform(job)
    end
  end

  describe "uniqueness" do
    test "same event_id produces unique key conflict" do
      event_id = "evt_dup_#{System.unique_integer([:positive])}"

      {:ok, job1} =
        %{event: %{"type" => "checkout.session.completed", "id" => event_id}, event_id: event_id}
        |> WebhookWorker.new()
        |> Oban.insert()

      {:ok, job2} =
        %{event: %{"type" => "checkout.session.completed", "id" => event_id}, event_id: event_id}
        |> WebhookWorker.new()
        |> Oban.insert()

      assert job1.id == job2.id
    end
  end
end
