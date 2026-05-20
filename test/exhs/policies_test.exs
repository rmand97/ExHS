defmodule Exhs.PoliciesTest do
  use Exhs.DataCase, async: true

  alias Exhs.Accounts
  alias Exhs.Organizations

  defp unique_email, do: "user-#{System.unique_integer([:positive])}@example.com"
  defp unique(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp create_user!(opts \\ []) do
    email = unique_email()

    user =
      Accounts.register_with_password!(email, "password123", "password123", authorize?: false)

    if opts[:superadmin] do
      Ash.Changeset.for_update(user, :update_profile, %{}, authorize?: false)
      |> Ash.Changeset.force_change_attribute(:is_superadmin, true)
      |> Ash.update!(authorize?: false)
    else
      user
    end
  end

  defp create_forening! do
    Organizations.create_forening!(
      %{name: unique("Forening"), slug: unique("slug"), subdomain: unique("sub")},
      authorize?: false
    )
  end

  defp invite!(forening, user, role \\ :member) do
    Organizations.invite_member!(user.id, %{role: role},
      tenant: forening.id,
      authorize?: false
    )
  end

  # ── Superadmin bypass ──────────────────────────────────────────────

  describe "superadmin bypass" do
    test "superadmin can read any user" do
      superadmin = create_user!(superadmin: true)
      other = create_user!()

      assert {:ok, found} = Accounts.get_user_by_id(other.id, actor: superadmin)
      assert found.id == other.id
    end

    test "superadmin can update any user's profile" do
      superadmin = create_user!(superadmin: true)
      other = create_user!()

      assert {:ok, updated} =
               Accounts.update_profile(other, %{first_name: "Changed"}, actor: superadmin)

      assert updated.first_name == "Changed"
    end

    test "superadmin can create a forening" do
      superadmin = create_user!(superadmin: true)

      assert {:ok, f} =
               Organizations.create_forening(
                 %{name: "New", slug: unique("slug"), subdomain: unique("sub")},
                 actor: superadmin
               )

      assert f.name == "New"
    end

    test "superadmin can archive a forening" do
      superadmin = create_user!(superadmin: true)
      forening = create_forening!()

      assert {:ok, archived} =
               Organizations.archive_forening(forening, actor: superadmin)

      assert archived.active == false
    end

    test "superadmin can read memberships in any forening" do
      superadmin = create_user!(superadmin: true)
      forening = create_forening!()
      user = create_user!()
      invite!(forening, user)

      memberships =
        Organizations.list_memberships!(
          tenant: forening.id,
          actor: superadmin
        )

      assert length(memberships) == 1
    end

    test "superadmin can set roles in any forening" do
      superadmin = create_user!(superadmin: true)
      forening = create_forening!()
      user = create_user!()
      membership = invite!(forening, user)

      assert {:ok, updated} =
               Organizations.set_member_role(membership, %{role: :admin},
                 tenant: forening.id,
                 actor: superadmin
               )

      assert updated.role == :admin
    end
  end

  # ── Forening policies ──────────────────────────────────────────────

  describe "Forening policies" do
    test "non-superadmin cannot create a forening" do
      user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.create_forening(
                 %{name: "Nope", slug: unique("slug"), subdomain: unique("sub")},
                 actor: user
               )
    end

    test "non-superadmin cannot archive a forening" do
      user = create_user!()
      forening = create_forening!()
      invite!(forening, user, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.archive_forening(forening, actor: user)
    end

    test "any authenticated user can read foreninger" do
      user = create_user!()
      forening = create_forening!()

      foreninger = Organizations.list_foreninger!(actor: user)
      ids = Enum.map(foreninger, & &1.id)
      assert forening.id in ids
    end

    test "admin can update forening" do
      user = create_user!()
      forening = create_forening!()
      invite!(forening, user, :admin)

      assert {:ok, updated} =
               Organizations.update_forening(
                 forening,
                 %{name: "Updated Name"},
                 tenant: forening.id,
                 actor: user
               )

      assert updated.name == "Updated Name"
    end

    test "board member cannot update forening" do
      user = create_user!()
      forening = create_forening!()
      invite!(forening, user, :board)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.update_forening(
                 forening,
                 %{name: "Nope"},
                 tenant: forening.id,
                 actor: user
               )
    end

    test "regular member cannot update forening" do
      user = create_user!()
      forening = create_forening!()
      invite!(forening, user, :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.update_forening(
                 forening,
                 %{name: "Nope"},
                 tenant: forening.id,
                 actor: user
               )
    end

    test "unauthenticated user cannot read foreninger" do
      create_forening!()
      assert Organizations.list_foreninger!(actor: nil) == []
    end
  end

  # ── Membership policies ────────────────────────────────────────────

  describe "Membership — join (self-service)" do
    test "authenticated user can join a forening" do
      user = create_user!()
      forening = create_forening!()

      assert {:ok, membership} =
               Organizations.join_forening(tenant: forening.id, actor: user)

      assert membership.user_id == user.id
      assert membership.role == :member
      assert membership.status == :active
    end

    test "unauthenticated user cannot join" do
      forening = create_forening!()

      assert {:error, _} = Organizations.join_forening(tenant: forening.id, actor: nil)
    end
  end

  describe "Membership — invite" do
    test "admin can invite members" do
      admin = create_user!()
      forening = create_forening!()
      invite!(forening, admin, :admin)
      new_user = create_user!()

      assert {:ok, m} =
               Organizations.invite_member(new_user.id,
                 tenant: forening.id,
                 actor: admin
               )

      assert m.user_id == new_user.id
    end

    test "board member cannot invite" do
      board = create_user!()
      forening = create_forening!()
      invite!(forening, board, :board)
      new_user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.invite_member(new_user.id,
                 tenant: forening.id,
                 actor: board
               )
    end

    test "regular member cannot invite" do
      member = create_user!()
      forening = create_forening!()
      invite!(forening, member, :member)
      new_user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.invite_member(new_user.id,
                 tenant: forening.id,
                 actor: member
               )
    end
  end

  describe "Membership — read" do
    test "admin can see all members in their forening" do
      admin = create_user!()
      member = create_user!()
      forening = create_forening!()
      invite!(forening, admin, :admin)
      invite!(forening, member, :member)

      memberships = Organizations.list_memberships!(tenant: forening.id, actor: admin)
      assert length(memberships) == 2
    end

    test "board member can see all members" do
      board = create_user!()
      member = create_user!()
      forening = create_forening!()
      invite!(forening, board, :board)
      invite!(forening, member, :member)

      memberships = Organizations.list_memberships!(tenant: forening.id, actor: board)
      assert length(memberships) == 2
    end

    test "regular member can only see own membership" do
      admin = create_user!()
      member = create_user!()
      forening = create_forening!()
      invite!(forening, admin, :admin)
      invite!(forening, member, :member)

      memberships = Organizations.list_memberships!(tenant: forening.id, actor: member)
      assert length(memberships) == 1
      assert hd(memberships).user_id == member.id
    end

    test "non-member cannot see any memberships" do
      outsider = create_user!()
      member = create_user!()
      forening = create_forening!()
      invite!(forening, member, :member)

      memberships = Organizations.list_memberships!(tenant: forening.id, actor: outsider)
      assert Enum.empty?(memberships)
    end
  end

  describe "Membership — activate / deactivate" do
    test "admin can deactivate a member" do
      admin = create_user!()
      member = create_user!()
      forening = create_forening!()
      invite!(forening, admin, :admin)
      m = invite!(forening, member, :member)

      assert {:ok, deactivated} =
               Organizations.deactivate_member(m, tenant: forening.id, actor: admin)

      assert deactivated.status == :inactive
    end

    test "admin can activate a member" do
      admin = create_user!()
      member = create_user!()
      forening = create_forening!()
      invite!(forening, admin, :admin)
      m = invite!(forening, member, :member)
      {:ok, d} = Organizations.deactivate_member(m, tenant: forening.id, actor: admin)

      assert {:ok, activated} =
               Organizations.activate_member(d, tenant: forening.id, actor: admin)

      assert activated.status == :active
    end

    test "regular member cannot deactivate others" do
      member1 = create_user!()
      member2 = create_user!()
      forening = create_forening!()
      invite!(forening, member1, :member)
      m2 = invite!(forening, member2, :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.deactivate_member(m2, tenant: forening.id, actor: member1)
    end

    test "board member cannot deactivate others" do
      board = create_user!()
      member = create_user!()
      forening = create_forening!()
      invite!(forening, board, :board)
      m = invite!(forening, member, :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.deactivate_member(m, tenant: forening.id, actor: board)
    end
  end

  describe "Membership — set_role" do
    test "admin can set roles" do
      admin = create_user!()
      member = create_user!()
      forening = create_forening!()
      invite!(forening, admin, :admin)
      m = invite!(forening, member, :member)

      assert {:ok, updated} =
               Organizations.set_member_role(m, %{role: :board},
                 tenant: forening.id,
                 actor: admin
               )

      assert updated.role == :board
    end

    test "regular member cannot set roles" do
      member1 = create_user!()
      member2 = create_user!()
      forening = create_forening!()
      invite!(forening, member1, :member)
      m2 = invite!(forening, member2, :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.set_member_role(m2, %{role: :admin},
                 tenant: forening.id,
                 actor: member1
               )
    end
  end

  describe "Membership — leave" do
    test "member can leave their own forening" do
      user = create_user!()
      forening = create_forening!()
      membership = invite!(forening, user, :member)

      assert :ok =
               Organizations.leave_forening!(membership,
                 tenant: forening.id,
                 actor: user
               )
    end

    test "member cannot make another member leave" do
      user1 = create_user!()
      user2 = create_user!()
      forening = create_forening!()
      invite!(forening, user1, :member)
      m2 = invite!(forening, user2, :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.leave_forening(m2, tenant: forening.id, actor: user1)
    end
  end

  # ── Last-admin safeguard ───────────────────────────────────────────

  describe "last-admin safeguard" do
    test "cannot demote the last admin" do
      admin = create_user!()
      forening = create_forening!()
      m = invite!(forening, admin, :admin)

      assert {:error, error} =
               Organizations.set_member_role(m, %{role: :member},
                 tenant: forening.id,
                 authorize?: false
               )

      assert Exception.message(error) =~ "last admin"
    end

    test "can demote an admin when another admin exists" do
      admin1 = create_user!()
      admin2 = create_user!()
      forening = create_forening!()
      m1 = invite!(forening, admin1, :admin)
      invite!(forening, admin2, :admin)

      assert {:ok, updated} =
               Organizations.set_member_role(m1, %{role: :member},
                 tenant: forening.id,
                 authorize?: false
               )

      assert updated.role == :member
    end

    test "last admin cannot leave" do
      admin = create_user!()
      forening = create_forening!()
      m = invite!(forening, admin, :admin)

      assert {:error, error} =
               Organizations.leave_forening(m,
                 tenant: forening.id,
                 authorize?: false
               )

      assert Exception.message(error) =~ "last admin"
    end

    test "admin can leave when another admin exists" do
      admin1 = create_user!()
      admin2 = create_user!()
      forening = create_forening!()
      m1 = invite!(forening, admin1, :admin)
      invite!(forening, admin2, :admin)

      assert :ok =
               Organizations.leave_forening!(m1,
                 tenant: forening.id,
                 authorize?: false
               )
    end
  end

  # ── Cross-tenant isolation ─────────────────────────────────────────

  describe "cross-tenant isolation" do
    test "admin of forening A cannot see members of forening B" do
      admin = create_user!()
      other_user = create_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite!(f_a, admin, :admin)
      invite!(f_b, other_user, :member)

      memberships = Organizations.list_memberships!(tenant: f_b.id, actor: admin)
      assert Enum.empty?(memberships)
    end

    test "admin of forening A cannot invite into forening B" do
      admin = create_user!()
      new_user = create_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite!(f_a, admin, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.invite_member(new_user.id,
                 tenant: f_b.id,
                 actor: admin
               )
    end

    test "admin of forening A cannot deactivate member in forening B" do
      admin = create_user!()
      user = create_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite!(f_a, admin, :admin)
      m = invite!(f_b, user, :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.deactivate_member(m, tenant: f_b.id, actor: admin)
    end

    test "admin of forening A cannot set roles in forening B" do
      admin = create_user!()
      user = create_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite!(f_a, admin, :admin)
      m = invite!(f_b, user, :member)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.set_member_role(m, %{role: :admin},
                 tenant: f_b.id,
                 actor: admin
               )
    end

    test "admin of forening A cannot update forening B" do
      admin = create_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite!(f_a, admin, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.update_forening(
                 f_b,
                 %{name: "Hijacked"},
                 tenant: f_b.id,
                 actor: admin
               )
    end

    test "memberships from forening A don't leak into forening B queries" do
      user = create_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite!(f_a, user, :admin)

      memberships = Organizations.list_memberships!(tenant: f_b.id, authorize?: false)
      user_ids = Enum.map(memberships, & &1.user_id)
      refute user.id in user_ids
    end

    test "user who is member in both foreninger sees correct scoping" do
      user = create_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite!(f_a, user, :admin)
      invite!(f_b, user, :member)

      a_members = Organizations.list_memberships!(tenant: f_a.id, actor: user)
      b_members = Organizations.list_memberships!(tenant: f_b.id, actor: user)

      assert length(a_members) == 1
      assert hd(a_members).forening_id == f_a.id

      assert length(b_members) == 1
      assert hd(b_members).forening_id == f_b.id
    end
  end

  # ── Scope integration ──────────────────────────────────────────────

  describe "Exhs.Scope integration with policies" do
    test "scope passes actor and tenant correctly for authorized access" do
      admin = create_user!()
      member = create_user!()
      forening = create_forening!()
      invite!(forening, admin, :admin)
      invite!(forening, member, :member)

      scope = %Exhs.Scope{actor: admin, tenant: forening.id}
      memberships = Organizations.list_memberships!(scope: scope)
      assert length(memberships) == 2
    end

    test "scope respects member-level read filtering" do
      admin = create_user!()
      member = create_user!()
      forening = create_forening!()
      invite!(forening, admin, :admin)
      invite!(forening, member, :member)

      scope = %Exhs.Scope{actor: member, tenant: forening.id}
      memberships = Organizations.list_memberships!(scope: scope)
      assert length(memberships) == 1
      assert hd(memberships).user_id == member.id
    end

    test "scope with nil actor is rejected for protected actions" do
      forening = create_forening!()
      scope = %Exhs.Scope{actor: nil, tenant: forening.id}

      assert {:error, _} = Organizations.join_forening(scope: scope)
    end
  end
end
