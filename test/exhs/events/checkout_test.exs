defmodule Exhs.Events.CheckoutTest do
  use Exhs.DataCase, async: false

  import Exhs.Test.Builders

  alias Exhs.Billing
  alias Exhs.Billing.StripeClient.Stub
  alias Exhs.Events
  alias Exhs.Events.ReservationExpiry

  defp setup_paid! do
    forening = create_forening!()
    activate_stripe_connect!(forening)
    forening = Ash.reload!(forening, authorize?: false)
    user = register_user!()
    invite_member!(forening, user, :member)
    membership = membership_for!(forening, user)
    event = create_published_event!(forening, %{membership_required: false})
    %{forening: forening, user: user, membership: membership, event: event}
  end

  defp checkout(forening, order) do
    Events.checkout_order(order,
      tenant: forening.id,
      success_url: "https://x/ok",
      cancel_url: "https://x/no"
    )
  end

  describe "free checkout" do
    test "confirms in place with no Stripe call and no payment" do
      %{forening: f, membership: m, event: e} = setup_paid!()
      Stub.set_response(:create_checkout_session, {:error, :should_not_be_called})
      tt = create_ticket_type!(f, e, %{price_cents: 0})
      order = create_order!(f, m, e)
      item = add_ticket_item!(f, order, tt)

      assert {:ok, %{order: paid, checkout_url: nil}} = checkout(f, order)
      assert paid.status == :paid
      assert paid.held_until == nil

      {:ok, reg} =
        Events.get_registration_by_id(item.registration_id, tenant: f.id, authorize?: false)

      assert reg.status == :confirmed

      {:ok, loaded} = Events.get_order(order.id, tenant: f.id, authorize?: false)
      assert loaded.payment == nil
    end
  end

  describe "paid checkout" do
    test "builds a session, stores id, sets hold, moves to pending_payment" do
      %{forening: f, membership: m, event: e} = setup_paid!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      addon = create_add_on!(f, e, %{price_cents: 5_000})
      order = create_order!(f, m, e)
      add_ticket_item!(f, order, tt)
      add_addon_item!(f, order, addon)

      assert {:ok, %{order: pending, checkout_url: url}} = checkout(f, order)
      assert url =~ "stripe.test/checkout"
      assert pending.status == :pending_payment
      assert pending.stripe_checkout_session_id
      assert pending.held_until
      assert pending.total_cents == 15_000
    end

    test "empty order (no ticket) is rejected" do
      %{forening: f, membership: m, event: e} = setup_paid!()
      order = create_order!(f, m, e)

      assert {:error, :order_requires_ticket} = checkout(f, order)
    end

    test "addon without a ticket is rejected at checkout" do
      %{forening: f, membership: m, event: e} = setup_paid!()
      addon = create_add_on!(f, e, %{price_cents: 5_000})
      order = create_order!(f, m, e)
      add_addon_item!(f, order, addon)

      assert {:error, :order_requires_ticket} = checkout(f, order)
    end

    test "Stripe session failure leaves order building and releases the hold" do
      %{forening: f, membership: m, event: e} = setup_paid!()
      Stub.set_response(:create_checkout_session, {:error, :stripe_down})
      tt = create_ticket_type!(f, e, %{price_cents: 10_000, capacity: 1})
      order = create_order!(f, m, e)
      item = add_ticket_item!(f, order, tt)

      assert {:error, :stripe_down} = checkout(f, order)

      {:ok, reloaded} = Events.get_order(order.id, tenant: f.id, authorize?: false)
      assert reloaded.status == :building

      {:ok, reg} =
        Events.get_registration_by_id(item.registration_id, tenant: f.id, authorize?: false)

      assert reg.status == :cancelled
      assert Events.Capacity.seats_taken(tt.id, f.id) == 0
    end

    test "last seat: a held seat blocks the next paid checkout" do
      %{forening: f, membership: m1, event: e} = setup_paid!()
      user2 = register_user!()
      invite_member!(f, user2, :member)
      m2 = membership_for!(f, user2)
      tt = create_ticket_type!(f, e, %{price_cents: 10_000, capacity: 1})

      o1 = create_order!(f, m1, e)
      add_ticket_item!(f, o1, tt)
      assert {:ok, %{order: %{status: :pending_payment}}} = checkout(f, o1)

      o2 = create_order!(f, m2, e)
      add_ticket_item!(f, o2, tt)
      assert {:error, _} = checkout(f, o2)
    end
  end

  describe "webhook: checkout.session.completed" do
    test "marks order paid, confirms registrations, records an order payment" do
      %{forening: f, membership: m, event: e} = setup_paid!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      order = create_order!(f, m, e)
      item = add_ticket_item!(f, order, tt)
      {:ok, %{order: pending}} = checkout(f, order)

      apply_completed(f, pending, "pi_abc")

      {:ok, paid} = Events.get_order(order.id, tenant: f.id, authorize?: false)
      assert paid.status == :paid
      assert paid.paid_at
      assert paid.held_until == nil
      assert paid.payment.payable_type == :order
      assert paid.payment.amount_cents == 10_000

      {:ok, reg} =
        Events.get_registration_by_id(item.registration_id, tenant: f.id, authorize?: false)

      assert reg.status == :confirmed
    end

    test "delivered twice is idempotent — single payment" do
      %{forening: f, membership: m, event: e} = setup_paid!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      order = create_order!(f, m, e)
      add_ticket_item!(f, order, tt)
      {:ok, %{order: pending}} = checkout(f, order)

      apply_completed(f, pending, "pi_dupe")
      apply_completed(f, pending, "pi_dupe")

      {:ok, payments} = Billing.list_payments(tenant: f.id, authorize?: false)
      order_payments = Enum.filter(payments, &(&1.payable_type == :order))
      assert length(order_payments) == 1
    end

    test "unknown session id is a no-op" do
      %{forening: f} = setup_paid!()

      event = %{
        "type" => "checkout.session.completed",
        "account" => f.stripe_account_id,
        "data" => %{"object" => %{"id" => "cs_missing", "payment_intent" => "pi_x"}}
      }

      assert :ok = Billing.Webhook.apply_event(event)
    end
  end

  describe "webhook: charge.refunded for an order" do
    test "refunds payment and frees the seat" do
      %{forening: f, membership: m, event: e} = setup_paid!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000, capacity: 1})
      order = create_order!(f, m, e)
      item = add_ticket_item!(f, order, tt)
      {:ok, %{order: pending}} = checkout(f, order)
      apply_completed(f, pending, "pi_refund")

      refund = %{
        "type" => "charge.refunded",
        "account" => f.stripe_account_id,
        "data" => %{"object" => %{"payment_intent" => "pi_refund"}}
      }

      assert {:ok, _} = Billing.Webhook.apply_event(refund)

      {:ok, reg} =
        Events.get_registration_by_id(item.registration_id, tenant: f.id, authorize?: false)

      assert reg.status == :cancelled
      assert Events.Capacity.seats_taken(tt.id, f.id) == 0
    end
  end

  describe "ReservationExpiry worker" do
    test "expires a lapsed hold, cancels the order and registration" do
      %{forening: f, membership: m, event: e} = setup_paid!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000, capacity: 1})
      order = create_order!(f, m, e)
      item = add_ticket_item!(f, order, tt)

      {:ok, reg} =
        Events.get_registration_by_id(item.registration_id, tenant: f.id, authorize?: false)

      # Simulate a hold that has already lapsed.
      Events.hold_registration!(reg, %{minutes: -1}, tenant: f.id, authorize?: false)

      {:ok, pending} =
        Events.begin_order_checkout(
          order,
          %{
            stripe_checkout_session_id: "cs_x",
            held_until: DateTime.add(DateTime.utc_now(), -60)
          },
          tenant: f.id,
          authorize?: false
        )

      job = %Oban.Job{args: %{"order_id" => pending.id, "tenant" => f.id}}
      assert :ok = ReservationExpiry.perform(job)

      {:ok, expired} = Events.get_order(order.id, tenant: f.id, authorize?: false)
      assert expired.status == :expired

      {:ok, freed} =
        Events.get_registration_by_id(item.registration_id, tenant: f.id, authorize?: false)

      assert freed.status == :cancelled
    end

    test "does not expire an already-paid order" do
      %{forening: f, membership: m, event: e} = setup_paid!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      order = create_order!(f, m, e)
      add_ticket_item!(f, order, tt)
      {:ok, %{order: pending}} = checkout(f, order)
      apply_completed(f, pending, "pi_paid_guard")

      job = %Oban.Job{args: %{"order_id" => pending.id, "tenant" => f.id}}
      assert :ok = ReservationExpiry.perform(job)

      {:ok, still_paid} = Events.get_order(order.id, tenant: f.id, authorize?: false)
      assert still_paid.status == :paid
    end

    test "expiry promotes the next waitlisted member" do
      %{forening: f, membership: m1, event: e} = setup_paid!()
      user2 = register_user!()
      invite_member!(f, user2, :member)
      m2 = membership_for!(f, user2)
      tt = create_ticket_type!(f, e, %{price_cents: 10_000, capacity: 1})

      # m1 holds the only seat via a paid reservation.
      o1 = create_order!(f, m1, e)
      i1 = add_ticket_item!(f, o1, tt)

      {:ok, r1} =
        Events.get_registration_by_id(i1.registration_id, tenant: f.id, authorize?: false)

      Events.hold_registration!(r1, %{minutes: 10}, tenant: f.id, authorize?: false)

      {:ok, pending} =
        Events.begin_order_checkout(o1, %{held_until: DateTime.add(DateTime.utc_now(), -60)},
          tenant: f.id,
          authorize?: false
        )

      # m2 joins the waitlist since the seat is held.
      {:ok, r2} =
        Events.register_for_event(%{ticket_type_id: tt.id, membership_id: m2.id},
          tenant: f.id,
          authorize?: false
        )

      assert r2.status == :waitlisted

      # Lapse m1's hold and run expiry; Oban runs the promoter inline.
      Events.hold_registration!(r1, %{minutes: -1}, tenant: f.id, authorize?: false)
      job = %Oban.Job{args: %{"order_id" => pending.id, "tenant" => f.id}}
      assert :ok = ReservationExpiry.perform(job)

      {:ok, promoted} = Events.get_registration_by_id(r2.id, tenant: f.id, authorize?: false)
      assert promoted.status == :confirmed
    end
  end

  defp apply_completed(forening, order, intent_id) do
    event = %{
      "type" => "checkout.session.completed",
      "account" => forening.stripe_account_id,
      "data" => %{
        "object" => %{
          "id" => order.stripe_checkout_session_id,
          "payment_intent" => intent_id,
          "amount_total" => order.total_cents,
          "currency" => "dkk"
        }
      }
    }

    Billing.Webhook.apply_event(event)
  end
end
