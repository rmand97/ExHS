defmodule Exhs.PoliciesTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.{Accounts, Organizations}

  describe "superadmin bypass" do
    test "superadmin can read any user" do
      superadmin = register_user!(superadmin: true)
      other = register_user!()

      assert {:ok, found} = Accounts.get_user_by_id(other.id, actor: superadmin)
      assert found.id == other.id
    end

    test "superadmin can update any user's profile" do
      superadmin = register_user!(superadmin: true)
      other = register_user!()

      assert {:ok, updated} =
               Accounts.update_profile(other, %{first_name: "Changed"}, actor: superadmin)

      assert updated.first_name == "Changed"
    end

    test "superadmin can create a forening" do
      superadmin = register_user!(superadmin: true)

      assert {:ok, f} =
               Organizations.create_forening(
                 %{name: "New", slug: "sa-slug", subdomain: "sa-sub"},
                 actor: superadmin
               )

      assert f.name == "New"
    end

    test "superadmin can archive a forening" do
      superadmin = register_user!(superadmin: true)
      forening = create_forening!()

      assert {:ok, archived} = Organizations.archive_forening(forening, actor: superadmin)
      assert archived.active == false
    end

    test "superadmin can read memberships in any forening" do
      superadmin = register_user!(superadmin: true)
      forening = create_forening!()
      user = register_user!()
      invite_member!(forening, user)

      memberships = Organizations.list_memberships!(tenant: forening.id, actor: superadmin)

      assert length(memberships) == 1
    end

    test "superadmin can set roles in any forening" do
      superadmin = register_user!(superadmin: true)
      forening = create_forening!()
      user = register_user!()
      membership = invite_member!(forening, user)

      assert {:ok, updated} =
               Organizations.set_member_role(membership, %{role: :admin},
                 tenant: forening.id,
                 actor: superadmin
               )

      assert updated.role == :admin
    end
  end

  describe "Forening policies" do
    test "non-superadmin cannot create a forening" do
      user = register_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.create_forening(
                 %{name: "Nope", slug: "nope", subdomain: "nope"},
                 actor: user
               )
    end

    test "non-superadmin cannot archive a forening" do
      user = register_user!()
      forening = create_forening!()
      invite_member!(forening, user, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.archive_forening(forening, actor: user)
    end

    test "any authenticated user can read foreninger" do
      user = register_user!()
      forening = create_forening!()

      ids = Organizations.list_foreninger!(actor: user) |> Enum.map(& &1.id)

      assert forening.id in ids
    end

    test "admin can update forening" do
      user = register_user!()
      forening = create_forening!()
      invite_member!(forening, user, :admin)

      assert {:ok, updated} =
               Organizations.update_forening(forening, %{name: "Updated"},
                 tenant: forening.id,
                 actor: user
               )

      assert updated.name == "Updated"
    end

    test "board member cannot update forening" do
      user = register_user!()
      forening = create_forening!()
      invite_member!(forening, user, :board)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.update_forening(forening, %{name: "Nope"},
                 tenant: forening.id,
                 actor: user
               )
    end

    test "regular member cannot update forening" do
      user = register_user!()
      forening = create_forening!()
      invite_member!(forening, user)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.update_forening(forening, %{name: "Nope"},
                 tenant: forening.id,
                 actor: user
               )
    end

    test "unauthenticated user cannot read foreninger" do
      create_forening!()

      assert Organizations.list_foreninger!(actor: nil) == []
    end
  end

  describe "Membership — join" do
    test "authenticated user can join a forening" do
      user = register_user!()
      forening = create_forening!()

      assert {:ok, membership} = Organizations.join_forening(tenant: forening.id, actor: user)

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
      admin = register_user!()
      forening = create_forening!()
      invite_member!(forening, admin, :admin)
      new_user = register_user!()

      assert {:ok, m} =
               Organizations.invite_member(new_user.id, tenant: forening.id, actor: admin)

      assert m.user_id == new_user.id
    end

    test "board member cannot invite" do
      board = register_user!()
      forening = create_forening!()
      invite_member!(forening, board, :board)
      new_user = register_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.invite_member(new_user.id, tenant: forening.id, actor: board)
    end

    test "regular member cannot invite" do
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, member)
      new_user = register_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.invite_member(new_user.id, tenant: forening.id, actor: member)
    end
  end

  describe "Membership — read" do
    test "admin can see all members" do
      admin = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, admin, :admin)
      invite_member!(forening, member)

      assert length(Organizations.list_memberships!(tenant: forening.id, actor: admin)) == 2
    end

    test "board member can see all members" do
      board = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, board, :board)
      invite_member!(forening, member)

      assert length(Organizations.list_memberships!(tenant: forening.id, actor: board)) == 2
    end

    test "regular member can only see own membership" do
      admin = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, admin, :admin)
      invite_member!(forening, member)

      memberships = Organizations.list_memberships!(tenant: forening.id, actor: member)

      assert length(memberships) == 1
      assert hd(memberships).user_id == member.id
    end

    test "non-member sees nothing" do
      outsider = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, member)

      assert Organizations.list_memberships!(tenant: forening.id, actor: outsider) == []
    end
  end

  describe "Membership — activate / deactivate" do
    test "admin can deactivate a member" do
      admin = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, admin, :admin)
      m = invite_member!(forening, member)

      assert {:ok, d} = Organizations.deactivate_member(m, tenant: forening.id, actor: admin)
      assert d.status == :inactive
    end

    test "admin can reactivate a member" do
      admin = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, admin, :admin)
      m = invite_member!(forening, member)
      {:ok, d} = Organizations.deactivate_member(m, tenant: forening.id, actor: admin)

      assert {:ok, a} = Organizations.activate_member(d, tenant: forening.id, actor: admin)
      assert a.status == :active
    end

    test "regular member cannot deactivate others" do
      member1 = register_user!()
      member2 = register_user!()
      forening = create_forening!()
      invite_member!(forening, member1)
      m2 = invite_member!(forening, member2)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.deactivate_member(m2, tenant: forening.id, actor: member1)
    end

    test "board member cannot deactivate others" do
      board = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, board, :board)
      m = invite_member!(forening, member)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.deactivate_member(m, tenant: forening.id, actor: board)
    end
  end

  describe "Membership — set_role" do
    test "admin can set roles" do
      admin = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, admin, :admin)
      m = invite_member!(forening, member)

      assert {:ok, updated} =
               Organizations.set_member_role(m, %{role: :board},
                 tenant: forening.id,
                 actor: admin
               )

      assert updated.role == :board
    end

    test "regular member cannot set roles" do
      member1 = register_user!()
      member2 = register_user!()
      forening = create_forening!()
      invite_member!(forening, member1)
      m2 = invite_member!(forening, member2)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.set_member_role(m2, %{role: :admin},
                 tenant: forening.id,
                 actor: member1
               )
    end
  end

  describe "Membership — leave" do
    test "member can leave own forening" do
      user = register_user!()
      forening = create_forening!()
      membership = invite_member!(forening, user)

      assert :ok =
               Organizations.leave_forening!(membership, tenant: forening.id, actor: user)
    end

    test "member cannot make another member leave" do
      user1 = register_user!()
      user2 = register_user!()
      forening = create_forening!()
      invite_member!(forening, user1)
      m2 = invite_member!(forening, user2)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.leave_forening(m2, tenant: forening.id, actor: user1)
    end
  end

  describe "last-admin safeguard" do
    test "cannot demote the last admin" do
      admin = register_user!()
      forening = create_forening!()
      m = invite_member!(forening, admin, :admin)

      assert {:error, error} =
               Organizations.set_member_role(m, %{role: :member},
                 tenant: forening.id,
                 authorize?: false
               )

      assert Exception.message(error) =~ "last admin"
    end

    test "can demote when another admin exists" do
      admin1 = register_user!()
      admin2 = register_user!()
      forening = create_forening!()
      m1 = invite_member!(forening, admin1, :admin)
      invite_member!(forening, admin2, :admin)

      assert {:ok, updated} =
               Organizations.set_member_role(m1, %{role: :member},
                 tenant: forening.id,
                 authorize?: false
               )

      assert updated.role == :member
    end

    test "last admin cannot leave" do
      admin = register_user!()
      forening = create_forening!()
      m = invite_member!(forening, admin, :admin)

      assert {:error, error} =
               Organizations.leave_forening(m, tenant: forening.id, authorize?: false)

      assert Exception.message(error) =~ "last admin"
    end

    test "admin can leave when another admin exists" do
      admin1 = register_user!()
      admin2 = register_user!()
      forening = create_forening!()
      m1 = invite_member!(forening, admin1, :admin)
      invite_member!(forening, admin2, :admin)

      assert :ok =
               Organizations.leave_forening!(m1, tenant: forening.id, authorize?: false)
    end
  end

  describe "cross-tenant isolation" do
    test "admin of forening A cannot see members of forening B" do
      admin = register_user!()
      other = register_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite_member!(f_a, admin, :admin)
      invite_member!(f_b, other)

      assert Organizations.list_memberships!(tenant: f_b.id, actor: admin) == []
    end

    test "admin of forening A cannot invite into forening B" do
      admin = register_user!()
      new_user = register_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite_member!(f_a, admin, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.invite_member(new_user.id, tenant: f_b.id, actor: admin)
    end

    test "admin of forening A cannot deactivate member in forening B" do
      admin = register_user!()
      user = register_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite_member!(f_a, admin, :admin)
      m = invite_member!(f_b, user)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.deactivate_member(m, tenant: f_b.id, actor: admin)
    end

    test "admin of forening A cannot set roles in forening B" do
      admin = register_user!()
      user = register_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite_member!(f_a, admin, :admin)
      m = invite_member!(f_b, user)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.set_member_role(m, %{role: :admin}, tenant: f_b.id, actor: admin)
    end

    test "admin of forening A cannot update forening B" do
      admin = register_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite_member!(f_a, admin, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.update_forening(f_b, %{name: "Hijacked"},
                 tenant: f_b.id,
                 actor: admin
               )
    end

    test "memberships don't leak across foreninger" do
      user = register_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite_member!(f_a, user, :admin)

      user_ids =
        Organizations.list_memberships!(tenant: f_b.id, authorize?: false)
        |> Enum.map(& &1.user_id)

      refute user.id in user_ids
    end

    test "user in both foreninger sees correct scoping" do
      user = register_user!()
      f_a = create_forening!()
      f_b = create_forening!()
      invite_member!(f_a, user, :admin)
      invite_member!(f_b, user)

      a_members = Organizations.list_memberships!(tenant: f_a.id, actor: user)
      b_members = Organizations.list_memberships!(tenant: f_b.id, actor: user)

      assert length(a_members) == 1
      assert hd(a_members).forening_id == f_a.id
      assert length(b_members) == 1
      assert hd(b_members).forening_id == f_b.id
    end
  end

  describe "Exhs.Scope integration" do
    test "scope passes actor and tenant for authorized access" do
      admin = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, admin, :admin)
      invite_member!(forening, member)

      assert length(Organizations.list_memberships!(scope: scope(admin, forening))) == 2
    end

    test "scope respects member-level read filtering" do
      admin = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, admin, :admin)
      invite_member!(forening, member)

      memberships = Organizations.list_memberships!(scope: scope(member, forening))

      assert length(memberships) == 1
      assert hd(memberships).user_id == member.id
    end

    test "scope with nil actor rejected for protected actions" do
      forening = create_forening!()
      scope = %Exhs.Scope{actor: nil, tenant: forening.id}

      assert {:error, _} = Organizations.join_forening(scope: scope)
    end
  end
end
