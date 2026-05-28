defmodule Exhs.MemberQueriesTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  describe "my_memberships" do
    test "returns memberships across multiple foreninger" do
      user = register_user!()
      f1 = create_forening!(%{name: "Fodboldklubben"})
      f2 = create_forening!(%{name: "Skakklubben"})
      join_forening!(f1, user)
      join_forening!(f2, user)

      {:ok, memberships} = Exhs.Organizations.list_my_memberships(actor: user)

      assert length(memberships) == 2
      names = Enum.map(memberships, & &1.forening.name) |> Enum.sort()
      assert names == ["Fodboldklubben", "Skakklubben"]
    end

    test "does not return other users' memberships" do
      user = register_user!()
      other = register_user!()
      f1 = create_forening!()
      join_forening!(f1, user)
      join_forening!(f1, other)

      {:ok, memberships} = Exhs.Organizations.list_my_memberships(actor: user)

      assert length(memberships) == 1
      assert hd(memberships).user_id == user.id
    end

    test "works without a tenant" do
      user = register_user!()
      f1 = create_forening!()
      join_forening!(f1, user)

      {:ok, memberships} = Exhs.Organizations.list_my_memberships(actor: user)
      assert length(memberships) == 1
    end

    test "requires an actor" do
      assert {:error, %Ash.Error.Invalid{}} =
               Exhs.Organizations.list_my_memberships()
    end

    test "loads forening relationship" do
      user = register_user!()
      f1 = create_forening!(%{name: "Testforening"})
      join_forening!(f1, user)

      {:ok, [membership]} = Exhs.Organizations.list_my_memberships(actor: user)
      assert membership.forening.name == "Testforening"
    end
  end

  describe "my_registrations" do
    test "returns registrations across multiple foreninger" do
      user = register_user!()
      f1 = create_forening!()
      f2 = create_forening!()
      m1 = join_forening!(f1, user)
      m2 = join_forening!(f2, user)

      event1 = create_published_event!(f1, %{title: "Fodboldkamp"})
      event2 = create_published_event!(f2, %{title: "Skakturnering"})
      tt1 = create_ticket_type!(f1, event1)
      tt2 = create_ticket_type!(f2, event2)
      register_for_event!(f1, m1, tt1)
      register_for_event!(f2, m2, tt2)

      {:ok, registrations} = Exhs.Events.list_my_registrations(actor: user)

      assert length(registrations) == 2
      event_titles = Enum.map(registrations, & &1.ticket_type.event.title) |> Enum.sort()
      assert event_titles == ["Fodboldkamp", "Skakturnering"]
    end

    test "does not return other users' registrations" do
      user = register_user!()
      other = register_user!()
      f1 = create_forening!()
      _m1 = join_forening!(f1, user)
      m2 = join_forening!(f1, other)

      event = create_published_event!(f1)
      tt = create_ticket_type!(f1, event)
      register_for_event!(f1, m2, tt)

      {:ok, registrations} = Exhs.Events.list_my_registrations(actor: user)
      assert registrations == []
    end

    test "requires an actor" do
      assert {:error, %Ash.Error.Invalid{}} =
               Exhs.Events.list_my_registrations()
    end
  end

  describe "my_subscriptions" do
    test "returns subscriptions across foreninger" do
      user = register_user!()
      f1 = create_forening!()
      m1 = join_forening!(f1, user)

      Exhs.Billing.create_subscription!(
        %{
          membership_id: m1.id,
          stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_test",
          status: :active,
          current_period_start: DateTime.utc_now(),
          current_period_end: DateTime.add(DateTime.utc_now(), 365, :day)
        },
        tenant: f1.id,
        authorize?: false
      )

      {:ok, subs} = Exhs.Billing.list_my_subscriptions(actor: user)
      assert length(subs) == 1
      assert hd(subs).status == :active
    end

    test "does not return other users' subscriptions" do
      user = register_user!()
      other = register_user!()
      f1 = create_forening!()
      _m1 = join_forening!(f1, user)
      m2 = join_forening!(f1, other)

      Exhs.Billing.create_subscription!(
        %{
          membership_id: m2.id,
          stripe_subscription_id: "sub_other_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_other",
          status: :active,
          current_period_start: DateTime.utc_now(),
          current_period_end: DateTime.add(DateTime.utc_now(), 365, :day)
        },
        tenant: f1.id,
        authorize?: false
      )

      {:ok, subs} = Exhs.Billing.list_my_subscriptions(actor: user)
      assert subs == []
    end
  end

  describe "my_payments" do
    test "returns payments for actor's memberships" do
      user = register_user!()
      f1 = create_forening!()
      m1 = join_forening!(f1, user)

      Exhs.Billing.record_payment!(
        %{
          payable_type: :subscription,
          payable_id: m1.id,
          amount_cents: 30_000,
          currency: "DKK",
          status: :succeeded,
          description: "Kontingent",
          paid_at: DateTime.utc_now()
        },
        tenant: f1.id,
        authorize?: false
      )

      {:ok, payments} = Exhs.Billing.list_my_payments([m1.id], actor: user)
      assert length(payments) == 1
      assert hd(payments).amount_cents == 30_000
    end

    test "does not return other users' payments" do
      user = register_user!()
      other = register_user!()
      f1 = create_forening!()
      m1 = join_forening!(f1, user)
      m2 = join_forening!(f1, other)

      Exhs.Billing.record_payment!(
        %{
          payable_type: :subscription,
          payable_id: m2.id,
          amount_cents: 10_000,
          currency: "DKK",
          status: :succeeded,
          paid_at: DateTime.utc_now()
        },
        tenant: f1.id,
        authorize?: false
      )

      {:ok, payments} = Exhs.Billing.list_my_payments([m1.id], actor: user)
      assert payments == []
    end
  end
end
