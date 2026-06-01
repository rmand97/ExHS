defmodule Exhs.SuperadminTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Organizations

  defp emailed?(addr) do
    receive do
      {:email, %Swoosh.Email{to: to}} ->
        Enum.any?(to, fn {_name, a} -> a == addr end) or emailed?(addr)
    after
      0 -> false
    end
  end

  describe "provision_forening/3" do
    test "creates a forening, its first admin, and emails a sign-in link" do
      superadmin = register_user!(superadmin: true)
      email = "founder_#{System.unique_integer([:positive])}@example.com"
      sub = "klub#{System.unique_integer([:positive])}"

      assert {:ok, forening} =
               Organizations.provision_forening(
                 %{name: "Ny Klub", subdomain: sub, slug: sub},
                 email,
                 superadmin
               )

      assert forening.name == "Ny Klub"
      assert forening.active

      {:ok, user} = Exhs.Accounts.get_user_by_email(email, authorize?: false)

      members =
        Organizations.list_memberships!(tenant: forening.id, load: [:user], authorize?: false)

      admin = Enum.find(members, &(&1.user_id == user.id))
      assert admin.role == :admin
      assert admin.status == :active

      assert emailed?(email)
    end

    test "a non-superadmin cannot provision a forening" do
      regular = register_user!()
      sub = "klub#{System.unique_integer([:positive])}"

      assert {:error, _} =
               Organizations.provision_forening(
                 %{name: "Hack", subdomain: sub, slug: sub},
                 "x@example.com",
                 regular
               )
    end

    test "a duplicate subdomain is rejected" do
      superadmin = register_user!(superadmin: true)
      existing = create_forening!(%{subdomain: "taget"})

      assert {:error, _} =
               Organizations.provision_forening(
                 %{name: "Konflikt", subdomain: existing.subdomain, slug: "konflikt-slug"},
                 "dup@example.com",
                 superadmin
               )
    end
  end
end
