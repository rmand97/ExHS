defmodule Exhs.OrganizationsTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Organizations

  describe "create_forening" do
    test "creates with valid attributes" do
      forening = create_forening!(%{name: "TestKlub", slug: "testklub", subdomain: "testklub"})

      assert forening.name == "TestKlub"
      assert forening.slug == "testklub"
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

      assert Organizations.get_forening_by_id!(forening.id, authorize?: false).id == forening.id
    end

    test "finds by slug" do
      forening = create_forening!(%{slug: "my-slug"})

      assert Organizations.get_forening_by_slug!("my-slug", authorize?: false).id == forening.id
    end

    test "finds by subdomain" do
      forening = create_forening!(%{subdomain: "my-sub"})

      assert Organizations.get_forening_by_subdomain!("my-sub", authorize?: false).id ==
               forening.id
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

      archived = Organizations.archive_forening!(forening, authorize?: false)

      assert archived.active == false
    end

    test "archived forening still retrievable and in listings" do
      forening = create_forening!()
      Organizations.archive_forening!(forening, authorize?: false)

      found = Organizations.get_forening_by_id!(forening.id, authorize?: false)
      assert found.active == false

      ids = Organizations.list_foreninger!(authorize?: false) |> Enum.map(& &1.id)
      assert forening.id in ids
    end
  end

  describe "invite_member" do
    test "creates an active membership with given role" do
      forening = create_forening!()
      user = register_user!()

      membership = invite_member!(forening, user, :admin)

      assert membership.user_id == user.id
      assert membership.forening_id == forening.id
      assert membership.role == :admin
      assert membership.status == :active
      assert membership.joined_at
    end

    test "defaults role to member" do
      forening = create_forening!()
      user = register_user!()

      membership = invite_member!(forening, user)

      assert membership.role == :member
    end

    test "rejects duplicate user in same forening" do
      forening = create_forening!()
      user = register_user!()
      invite_member!(forening, user)

      assert_raise Ash.Error.Invalid, fn ->
        invite_member!(forening, user)
      end
    end

    test "same user can join multiple foreninger" do
      forening_a = create_forening!()
      forening_b = create_forening!()
      user = register_user!()

      m1 = invite_member!(forening_a, user)
      m2 = invite_member!(forening_b, user)

      assert m1.forening_id == forening_a.id
      assert m2.forening_id == forening_b.id
    end
  end

  describe "activate / deactivate" do
    test "deactivate sets inactive and deactivated_at" do
      forening = create_forening!()
      user = register_user!()
      membership = invite_member!(forening, user)

      deactivated =
        Organizations.deactivate_member!(membership, tenant: forening.id, authorize?: false)

      assert deactivated.status == :inactive
      assert deactivated.deactivated_at
    end

    test "activate restores active and clears deactivated_at" do
      forening = create_forening!()
      user = register_user!()
      membership = invite_member!(forening, user)

      deactivated =
        Organizations.deactivate_member!(membership, tenant: forening.id, authorize?: false)

      activated =
        Organizations.activate_member!(deactivated, tenant: forening.id, authorize?: false)

      assert activated.status == :active
      assert activated.activated_at
      assert is_nil(activated.deactivated_at)
    end
  end

  describe "set_member_role" do
    test "changes the role" do
      forening = create_forening!()
      user = register_user!()
      membership = invite_member!(forening, user)

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
      user = register_user!()
      membership = invite_member!(forening, user)

      :ok = Organizations.leave_forening!(membership, tenant: forening.id, authorize?: false)

      assert Organizations.list_memberships!(tenant: forening.id, authorize?: false) == []
    end
  end

  describe "tenant isolation" do
    test "memberships are scoped to their forening" do
      forening_a = create_forening!()
      forening_b = create_forening!()
      user_a = register_user!()
      user_b = register_user!()

      invite_member!(forening_a, user_a)
      invite_member!(forening_b, user_b)

      a_members = Organizations.list_memberships!(tenant: forening_a.id, authorize?: false)
      b_members = Organizations.list_memberships!(tenant: forening_b.id, authorize?: false)

      assert length(a_members) == 1
      assert hd(a_members).user_id == user_a.id
      assert hd(b_members).user_id == user_b.id
    end
  end

  describe "Exhs.Scope" do
    test "passes actor and tenant to code interfaces" do
      forening = create_forening!()
      user = register_user!()
      invite_member!(forening, user)

      memberships =
        Organizations.list_memberships!(scope: scope(user, forening), authorize?: false)

      assert length(memberships) == 1
      assert hd(memberships).user_id == user.id
    end
  end
end
