defmodule Exhs.BillingTest do
  use Exhs.DataCase, async: true

  alias Exhs.{Accounts, Billing, Organizations}

  defp unique(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp create_forening!(attrs \\ %{}) do
    defaults = %{
      name: "Forening #{System.unique_integer([:positive])}",
      slug: unique("slug"),
      subdomain: unique("sub"),
      kontingent_stripe_price_id: "price_test_kontingent"
    }

    Organizations.create_forening!(Map.merge(defaults, attrs), authorize?: false)
  end

  defp activate_connect!(forening) do
    Organizations.set_forening_stripe_account!(
      forening,
      %{
        stripe_account_id: "acct_test_#{System.unique_integer([:positive])}",
        stripe_account_status: :active
      },
      authorize?: false
    )
  end

  defp create_user! do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    Accounts.register_with_password!(email, "password123", "password123", authorize?: false)
  end

  defp invite_admin!(user, forening) do
    Organizations.invite_member!(user.id, %{role: :admin},
      tenant: forening.id,
      authorize?: false
    )
  end

  defp invite_member!(user, forening) do
    Organizations.invite_member!(user.id, tenant: forening.id, authorize?: false)
  end

  describe "start_onboarding/3" do
    test "creates connect account on first call and returns onboarding URL" do
      forening = create_forening!()
      admin = create_user!()
      invite_admin!(admin, forening)
      scope = %Exhs.Scope{actor: admin, tenant: forening.id}

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
      forening = create_forening!()
      member = create_user!()
      invite_member!(member, forening)
      scope = %Exhs.Scope{actor: member, tenant: forening.id}

      assert {:error, :forbidden} =
               Billing.start_onboarding(forening, scope,
                 refresh_url: "https://example.test/refresh",
                 return_url: "https://example.test/return"
               )
    end
  end

  describe "start_kontingent_subscription/3" do
    test "creates a Stripe customer and returns the checkout URL" do
      forening = create_forening!()
      forening = activate_connect!(forening)
      user = create_user!()
      membership = invite_member!(user, forening)
      scope = %Exhs.Scope{actor: user, tenant: forening.id}

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
      forening = create_forening!()
      user = create_user!()
      membership = invite_member!(user, forening)
      scope = %Exhs.Scope{actor: user, tenant: forening.id}

      assert {:error, :forening_billing_not_ready} =
               Billing.start_kontingent_subscription(membership, scope,
                 success_url: "https://example.test/ok",
                 cancel_url: "https://example.test/cancel"
               )
    end

    test "rejects an actor who is neither the membership owner nor an admin" do
      forening = create_forening!()
      forening = activate_connect!(forening)
      owner = create_user!()
      membership = invite_member!(owner, forening)
      stranger = create_user!()
      scope = %Exhs.Scope{actor: stranger, tenant: forening.id}

      assert {:error, :forbidden} =
               Billing.start_kontingent_subscription(membership, scope,
                 success_url: "https://example.test/ok",
                 cancel_url: "https://example.test/cancel"
               )
    end
  end
end
