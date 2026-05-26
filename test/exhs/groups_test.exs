defmodule Exhs.GroupsTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Organizations

  describe "Group CRUD" do
    test "admin can create a group" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)

      assert {:ok, group} =
               Organizations.create_group(
                 %{name: "Board Members", color: "#00ff00"},
                 tenant: forening.id,
                 actor: admin
               )

      assert group.name == "Board Members"
      assert group.color == "#00ff00"
    end

    test "admin can update a group" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      group = create_group!(forening, %{name: "Old Name"})

      assert {:ok, updated} =
               Organizations.update_group(group, %{name: "New Name"},
                 tenant: forening.id,
                 actor: admin
               )

      assert updated.name == "New Name"
    end

    test "admin can destroy a group" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      group = create_group!(forening)

      assert :ok = Organizations.destroy_group(group, tenant: forening.id, actor: admin)
    end

    test "group name must be unique within forening" do
      forening = create_forening!()
      create_group!(forening, %{name: "Duplicated"})

      assert_raise Ash.Error.Invalid, fn ->
        create_group!(forening, %{name: "Duplicated"})
      end
    end

    test "same group name allowed in different foreninger" do
      forening_a = create_forening!()
      forening_b = create_forening!()

      create_group!(forening_a, %{name: "Shared Name"})
      group_b = create_group!(forening_b, %{name: "Shared Name"})

      assert group_b.name == "Shared Name"
    end

    test "color must be valid hex" do
      forening = create_forening!()

      assert_raise Ash.Error.Invalid, fn ->
        create_group!(forening, %{name: "Bad Color", color: "not-hex"})
      end
    end

    test "active member can list groups" do
      forening = create_forening!()
      member = register_user!()
      join_forening!(forening, member)
      create_group!(forening, %{name: "Visible"})

      groups = Organizations.list_groups!(tenant: forening.id, actor: member)

      assert length(groups) == 1
      assert hd(groups).name == "Visible"
    end
  end

  describe "MemberGroup assignment" do
    test "admin can add a member to a group" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      member = register_user!()
      join_forening!(forening, member)
      group = create_group!(forening)
      membership = membership_for!(forening, member)

      assert {:ok, mg} =
               Organizations.add_member_to_group(
                 %{membership_id: membership.id, group_id: group.id},
                 tenant: forening.id,
                 actor: admin
               )

      assert mg.membership_id == membership.id
      assert mg.group_id == group.id
    end

    test "cannot add same member to same group twice" do
      forening = create_forening!()
      member = register_user!()
      join_forening!(forening, member)
      group = create_group!(forening)
      membership = membership_for!(forening, member)

      Organizations.add_member_to_group!(
        %{membership_id: membership.id, group_id: group.id},
        tenant: forening.id,
        authorize?: false
      )

      assert_raise Ash.Error.Invalid, fn ->
        Organizations.add_member_to_group!(
          %{membership_id: membership.id, group_id: group.id},
          tenant: forening.id,
          authorize?: false
        )
      end
    end

    test "admin can remove a member from a group" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      member = register_user!()
      join_forening!(forening, member)
      group = create_group!(forening)
      membership = membership_for!(forening, member)

      mg =
        Organizations.add_member_to_group!(
          %{membership_id: membership.id, group_id: group.id},
          tenant: forening.id,
          authorize?: false
        )

      assert :ok =
               Organizations.remove_member_from_group(mg, tenant: forening.id, actor: admin)
    end

    test "groups loadable via membership" do
      forening = create_forening!()
      member = register_user!()
      join_forening!(forening, member)
      group = create_group!(forening, %{name: "Loaded Group"})
      membership = membership_for!(forening, member)

      Organizations.add_member_to_group!(
        %{membership_id: membership.id, group_id: group.id},
        tenant: forening.id,
        authorize?: false
      )

      loaded = Ash.load!(membership, [:groups], tenant: forening.id, authorize?: false)

      assert length(loaded.groups) == 1
      assert hd(loaded.groups).name == "Loaded Group"
    end
  end

  describe "Group policies" do
    test "regular member cannot create groups" do
      forening = create_forening!()
      member = register_user!()
      join_forening!(forening, member)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.create_group(%{name: "Forbidden"},
                 tenant: forening.id,
                 actor: member
               )
    end

    test "regular member cannot update groups" do
      forening = create_forening!()
      member = register_user!()
      join_forening!(forening, member)
      group = create_group!(forening)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.update_group(group, %{name: "Nope"},
                 tenant: forening.id,
                 actor: member
               )
    end

    test "regular member cannot destroy groups" do
      forening = create_forening!()
      member = register_user!()
      join_forening!(forening, member)
      group = create_group!(forening)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.destroy_group(group, tenant: forening.id, actor: member)
    end

    test "regular member cannot assign members to groups" do
      forening = create_forening!()
      member = register_user!()
      join_forening!(forening, member)
      group = create_group!(forening)
      membership = membership_for!(forening, member)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.add_member_to_group(
                 %{membership_id: membership.id, group_id: group.id},
                 tenant: forening.id,
                 actor: member
               )
    end

    test "unauthenticated user cannot list groups" do
      forening = create_forening!()
      create_group!(forening)

      assert Organizations.list_groups!(tenant: forening.id, actor: nil) == []
    end

    test "member of forening A cannot see forening B groups" do
      forening_a = create_forening!()
      forening_b = create_forening!()
      member = register_user!()
      join_forening!(forening_a, member)
      create_group!(forening_b, %{name: "Secret"})

      assert Organizations.list_groups!(tenant: forening_b.id, actor: member) == []
    end
  end
end
