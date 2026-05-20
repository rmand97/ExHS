defmodule Exhs.OrganizationsTest do
  use Exhs.DataCase, async: true

  alias Exhs.Accounts
  alias Exhs.Organizations

  defp unique(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp create_forening!(attrs \\ %{}) do
    defaults = %{
      name: "Forening #{System.unique_integer([:positive])}",
      slug: unique("slug"),
      subdomain: unique("sub")
    }

    Organizations.create_forening!(Map.merge(defaults, attrs), authorize?: false)
  end

  defp create_user! do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    Accounts.register_with_password!(email, "password123", "password123", authorize?: false)
  end

  describe "create_forening" do
    test "creates with valid attributes" do
      forening = create_forening!(%{name: "TestKlub", slug: "testklub", subdomain: "testklub"})

      assert forening.name == "TestKlub"
      assert forening.slug == "testklub"
      assert forening.subdomain == "testklub"
      assert forening.active == true
      assert forening.kontingent_currency == "DKK"
    end

    test "rejects duplicate slug" do
      create_forening!(%{slug: "dup-slug"})

      assert_raise Ash.Error.Invalid, fn ->
        create_forening!(%{slug: "dup-slug"})
      end
    end

    test "rejects duplicate subdomain" do
      create_forening!(%{subdomain: "dup-sub"})

      assert_raise Ash.Error.Invalid, fn ->
        create_forening!(%{subdomain: "dup-sub"})
      end
    end
  end

  describe "get_forening_by_*" do
    test "finds by id" do
      forening = create_forening!()
      found = Organizations.get_forening_by_id!(forening.id, authorize?: false)
      assert found.id == forening.id
    end

    test "finds by slug" do
      forening = create_forening!(%{slug: "my-slug"})
      found = Organizations.get_forening_by_slug!("my-slug", authorize?: false)
      assert found.id == forening.id
    end

    test "finds by subdomain" do
      forening = create_forening!(%{subdomain: "my-sub"})
      found = Organizations.get_forening_by_subdomain!("my-sub", authorize?: false)
      assert found.id == forening.id
    end
  end

  describe "update_forening" do
    test "updates allowed fields" do
      forening = create_forening!()

      updated =
        Organizations.update_forening!(
          forening,
          %{name: "New Name", kontingent_amount_cents: 50_000},
          authorize?: false
        )

      assert updated.name == "New Name"
      assert updated.kontingent_amount_cents == 50_000
    end
  end

  describe "archive_forening" do
    test "sets active to false" do
      forening = create_forening!()
      assert forening.active == true

      archived = Organizations.archive_forening!(forening, authorize?: false)
      assert archived.active == false
    end

    test "archived forening is still retrievable" do
      forening = create_forening!()
      Organizations.archive_forening!(forening, authorize?: false)

      found = Organizations.get_forening_by_id!(forening.id, authorize?: false)
      assert found.active == false
    end

    test "archived forening still appears in list" do
      forening = create_forening!()
      Organizations.archive_forening!(forening, authorize?: false)

      ids =
        Organizations.list_foreninger!(authorize?: false)
        |> Enum.map(& &1.id)

      assert forening.id in ids
    end
  end

  describe "list_foreninger" do
    test "returns all foreninger" do
      f1 = create_forening!()
      f2 = create_forening!()

      ids =
        Organizations.list_foreninger!(authorize?: false)
        |> Enum.map(& &1.id)

      assert f1.id in ids
      assert f2.id in ids
    end
  end

  describe "invite_member" do
    test "creates a membership in the forening" do
      forening = create_forening!()
      user = create_user!()

      membership =
        Organizations.invite_member!(user.id, %{role: :admin},
          tenant: forening.id,
          authorize?: false
        )

      assert membership.user_id == user.id
      assert membership.forening_id == forening.id
      assert membership.role == :admin
      assert membership.status == :active
      assert membership.joined_at
      assert membership.activated_at
    end

    test "defaults role to member" do
      forening = create_forening!()
      user = create_user!()

      membership =
        Organizations.invite_member!(user.id, tenant: forening.id, authorize?: false)

      assert membership.role == :member
    end

    test "rejects duplicate user in same forening" do
      forening = create_forening!()
      user = create_user!()

      Organizations.invite_member!(user.id, tenant: forening.id, authorize?: false)

      assert_raise Ash.Error.Invalid, fn ->
        Organizations.invite_member!(user.id, tenant: forening.id, authorize?: false)
      end
    end

    test "same user can join multiple foreninger" do
      f1 = create_forening!()
      f2 = create_forening!()
      user = create_user!()

      m1 = Organizations.invite_member!(user.id, tenant: f1.id, authorize?: false)
      m2 = Organizations.invite_member!(user.id, tenant: f2.id, authorize?: false)

      assert m1.forening_id == f1.id
      assert m2.forening_id == f2.id
    end
  end

  describe "activate_member / deactivate_member" do
    test "deactivate sets inactive and deactivated_at" do
      forening = create_forening!()
      user = create_user!()

      membership =
        Organizations.invite_member!(user.id, tenant: forening.id, authorize?: false)

      deactivated =
        Organizations.deactivate_member!(membership,
          tenant: forening.id,
          authorize?: false
        )

      assert deactivated.status == :inactive
      assert deactivated.deactivated_at
    end

    test "activate sets active and clears deactivated_at" do
      forening = create_forening!()
      user = create_user!()

      membership =
        Organizations.invite_member!(user.id, tenant: forening.id, authorize?: false)

      deactivated =
        Organizations.deactivate_member!(membership,
          tenant: forening.id,
          authorize?: false
        )

      activated =
        Organizations.activate_member!(deactivated,
          tenant: forening.id,
          authorize?: false
        )

      assert activated.status == :active
      assert activated.activated_at
      assert is_nil(activated.deactivated_at)
    end
  end

  describe "set_member_role" do
    test "changes the role" do
      forening = create_forening!()
      user = create_user!()

      membership =
        Organizations.invite_member!(user.id, tenant: forening.id, authorize?: false)

      assert membership.role == :member

      updated =
        Organizations.set_member_role!(membership, %{role: :board},
          tenant: forening.id,
          authorize?: false
        )

      assert updated.role == :board
    end
  end

  describe "leave_forening" do
    test "destroys the membership" do
      forening = create_forening!()
      user = create_user!()

      membership =
        Organizations.invite_member!(user.id, tenant: forening.id, authorize?: false)

      :ok = Organizations.leave_forening!(membership, tenant: forening.id, authorize?: false)

      memberships = Organizations.list_memberships!(tenant: forening.id, authorize?: false)
      assert Enum.empty?(memberships)
    end
  end

  describe "tenant isolation" do
    test "memberships are scoped to their forening" do
      f1 = create_forening!()
      f2 = create_forening!()
      u1 = create_user!()
      u2 = create_user!()

      Organizations.invite_member!(u1.id, tenant: f1.id, authorize?: false)
      Organizations.invite_member!(u2.id, tenant: f2.id, authorize?: false)

      f1_members = Organizations.list_memberships!(tenant: f1.id, authorize?: false)
      f2_members = Organizations.list_memberships!(tenant: f2.id, authorize?: false)

      assert length(f1_members) == 1
      assert length(f2_members) == 1
      assert hd(f1_members).user_id == u1.id
      assert hd(f2_members).user_id == u2.id
    end
  end

  describe "Exhs.Scope" do
    test "passes actor and tenant to code interfaces" do
      forening = create_forening!()
      user = create_user!()

      Organizations.invite_member!(user.id, tenant: forening.id, authorize?: false)

      scope = %Exhs.Scope{actor: user, tenant: forening.id}

      memberships = Organizations.list_memberships!(scope: scope, authorize?: false)
      assert length(memberships) == 1
      assert hd(memberships).user_id == user.id
    end
  end
end
