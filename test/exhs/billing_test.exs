defmodule Exhs.BillingTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.{Billing, Organizations}

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
        Ash.get!(Exhs.Organizations.Membership, membership.id,
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
  end
end
