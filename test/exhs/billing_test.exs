defmodule Exhs.BillingTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.{Billing, Organizations}
  alias Exhs.Billing.StripeClient.Stub
  alias Exhs.Organizations.Membership

  defp billing_forening! do
    create_forening!(%{kontingent_stripe_price_id: "price_test_kontingent"})
  end

  describe "start_onboarding/3" do
    test "creates connect account on first call and returns onboarding URL" do
      forening = billing_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      scope = scope(admin, forening)

      assert {:ok, url} =
               Billing.start_onboarding(forening, scope,
                 refresh_url: "https://example.test/refresh",
                 return_url: "https://example.test/return"
               )

      assert String.starts_with?(url, "https://stripe.test/connect/onboard/")

      updated = Organizations.get_forening_by_id!(forening.id, authorize?: false)
      assert updated.stripe_account_id
      assert updated.stripe_account_status == :onboarding
    end

    test "non-admin cannot trigger onboarding" do
      forening = billing_forening!()
      member = register_user!()
      invite_member!(forening, member)
      scope = scope(member, forening)

      assert {:error, :forbidden} =
               Billing.start_onboarding(forening, scope,
                 refresh_url: "https://example.test/refresh",
                 return_url: "https://example.test/return"
               )
    end
  end

  describe "start_onboarding/3 failure paths" do
    test "returns error when Stripe account creation fails" do
      forening = billing_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      scope = scope(admin, forening)

      Stub.set_response(
        :create_account,
        {:error, %{message: "Stripe unavailable", code: :api_error}}
      )

      assert {:error, _} =
               Billing.start_onboarding(forening, scope,
                 refresh_url: "https://example.test/refresh",
                 return_url: "https://example.test/return"
               )

      reloaded = Organizations.get_forening_by_id!(forening.id, authorize?: false)
      refute reloaded.stripe_account_id
    end

    test "returns error when account link creation fails" do
      forening = billing_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      scope = scope(admin, forening)

      Stub.set_response(
        :create_account_link,
        {:error, %{message: "timeout", code: :api_connection_error}}
      )

      assert {:error, _} =
               Billing.start_onboarding(forening, scope,
                 refresh_url: "https://example.test/refresh",
                 return_url: "https://example.test/return"
               )
    end
  end

  describe "start_kontingent_subscription/3" do
    test "creates a Stripe customer and returns the checkout URL" do
      forening = billing_forening!() |> activate_stripe_connect!()
      user = register_user!()
      membership = invite_member!(forening, user)
      scope = scope(user, forening)

      assert {:ok, url} =
               Billing.start_kontingent_subscription(membership, scope,
                 success_url: "https://example.test/ok",
                 cancel_url: "https://example.test/cancel"
               )

      assert String.starts_with?(url, "https://stripe.test/checkout/")

      reloaded =
        Ash.get!(Membership, membership.id,
          tenant: forening.id,
          authorize?: false
        )

      assert reloaded.stripe_customer_id
    end

    test "errors when forening connect status is not :active" do
      forening = billing_forening!()
      user = register_user!()
      membership = invite_member!(forening, user)
      scope = scope(user, forening)

      assert {:error, :forening_billing_not_ready} =
               Billing.start_kontingent_subscription(membership, scope,
                 success_url: "https://example.test/ok",
                 cancel_url: "https://example.test/cancel"
               )
    end

    test "rejects an actor who is neither the membership owner nor an admin" do
      forening = billing_forening!() |> activate_stripe_connect!()
      owner = register_user!()
      membership = invite_member!(forening, owner)
      stranger = register_user!()
      scope = scope(stranger, forening)

      assert {:error, :forbidden} =
               Billing.start_kontingent_subscription(membership, scope,
                 success_url: "https://example.test/ok",
                 cancel_url: "https://example.test/cancel"
               )
    end

    test "returns error when customer creation fails and does not half-commit" do
      forening = billing_forening!() |> activate_stripe_connect!()
      user = register_user!()
      membership = invite_member!(forening, user)
      scope = scope(user, forening)

      Stub.set_response(
        :create_customer,
        {:error, %{message: "card_declined", code: :card_error}}
      )

      assert {:error, _} =
               Billing.start_kontingent_subscription(membership, scope,
                 success_url: "https://example.test/ok",
                 cancel_url: "https://example.test/cancel"
               )

      reloaded =
        Ash.get!(Membership, membership.id,
          tenant: forening.id,
          authorize?: false
        )

      refute reloaded.stripe_customer_id
    end

    test "returns error when checkout session creation fails" do
      forening = billing_forening!() |> activate_stripe_connect!()
      user = register_user!()
      membership = invite_member!(forening, user)
      scope = scope(user, forening)

      Stub.set_response(
        :create_checkout_session,
        {:error, %{message: "api_error", code: :api_error}}
      )

      assert {:error, _} =
               Billing.start_kontingent_subscription(membership, scope,
                 success_url: "https://example.test/ok",
                 cancel_url: "https://example.test/cancel"
               )
    end
  end

  describe "cancel_kontingent_subscription/2" do
    test "returns error when Stripe update_subscription fails" do
      forening = billing_forening!() |> activate_stripe_connect!()
      user = register_user!()
      membership = invite_member!(forening, user)
      membership = set_stripe_customer!(forening, membership)
      scope = scope(user, forening)

      {:ok, sub} =
        Billing.create_subscription(
          %{
            membership_id: membership.id,
            stripe_subscription_id: "sub_cancel_test",
            stripe_customer_id: membership.stripe_customer_id,
            status: :active,
            cancel_at_period_end: false
          },
          tenant: forening.id,
          authorize?: false
        )

      Stub.set_response(
        :update_subscription,
        {:error, %{message: "timeout", code: :api_connection_error}}
      )

      assert {:error, _} = Billing.cancel_kontingent_subscription(sub, scope)

      reloaded =
        Billing.get_subscription_by_id!(sub.id, tenant: forening.id, authorize?: false)

      refute reloaded.cancel_at_period_end
    end
  end
end
