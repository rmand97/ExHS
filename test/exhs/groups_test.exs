defmodule Exhs.GroupsTest do
  use Exhs.DataCase, async: true

  alias Exhs.Accounts
  alias Exhs.Organizations

  defp unique_email, do: "user-#{System.unique_integer([:positive])}@example.com"

  defp setup_forening do
    Organizations.create_forening!(
      %{
        name: "Test Forening",
        slug: "test-#{System.unique_integer([:positive])}",
        subdomain: "test#{System.unique_integer([:positive])}"
      },
      authorize?: false
    )
  end

  defp setup_admin(forening) do
    user =
      Accounts.register_with_password!(unique_email(), "password123", "password123",
        authorize?: false
      )

    Organizations.invite_member!(
      user.id,
      %{role: :admin},
      tenant: forening.id,
      authorize?: false
    )

    user
  end

  defp setup_member(forening) do
    user =
      Accounts.register_with_password!(unique_email(), "password123", "password123",
        authorize?: false
      )

    Organizations.join_forening!(
      %{},
      tenant: forening.id,
      actor: user
    )

    user
  end

  defp create_group(forening, attrs \\ %{}) do
    defaults = %{name: "Group #{System.unique_integer([:positive])}", color: "#ff0000"}

    Organizations.create_group!(
      Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  defp get_membership(user, forening) do
    Organizations.list_memberships!(tenant: forening.id, authorize?: false)
    |> Enum.find(&(&1.user_id == user.id))
  end

  describe "Group CRUD" do
    test "admin can create a group" do
      forening = setup_forening()
      admin = setup_admin(forening)

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
      forening = setup_forening()
      admin = setup_admin(forening)
      group = create_group(forening, %{name: "Old Name"})

      assert {:ok, updated} =
               Organizations.update_group(group, %{name: "New Name"},
                 tenant: forening.id,
                 actor: admin
               )

      assert updated.name == "New Name"
    end

    test "admin can destroy a group" do
      forening = setup_forening()
      admin = setup_admin(forening)
      group = create_group(forening)

      assert :ok =
               Organizations.destroy_group(group,
                 tenant: forening.id,
                 actor: admin
               )
    end

    test "group name must be unique within forening" do
      forening = setup_forening()
      create_group(forening, %{name: "Duplicated"})

      assert_raise Ash.Error.Invalid, fn ->
        create_group(forening, %{name: "Duplicated"})
      end
    end

    test "same group name allowed in different foreninger" do
      forening_a = setup_forening()
      forening_b = setup_forening()

      create_group(forening_a, %{name: "Shared Name"})
      group_b = create_group(forening_b, %{name: "Shared Name"})

      assert group_b.name == "Shared Name"
    end

    test "color must be a valid hex color" do
      forening = setup_forening()

      assert_raise Ash.Error.Invalid, fn ->
        create_group(forening, %{name: "Bad Color", color: "not-hex"})
      end
    end

    test "active member can list groups" do
      forening = setup_forening()
      member = setup_member(forening)
      create_group(forening, %{name: "Visible"})

      groups = Organizations.list_groups!(tenant: forening.id, actor: member)
      assert length(groups) == 1
      assert hd(groups).name == "Visible"
    end
  end

  describe "MemberGroup assignment" do
    test "admin can add a member to a group" do
      forening = setup_forening()
      admin = setup_admin(forening)
      member = setup_member(forening)
      group = create_group(forening)
      membership = get_membership(member, forening)

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
      forening = setup_forening()
      member = setup_member(forening)
      group = create_group(forening)
      membership = get_membership(member, forening)

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
      forening = setup_forening()
      admin = setup_admin(forening)
      member = setup_member(forening)
      group = create_group(forening)
      membership = get_membership(member, forening)

      mg =
        Organizations.add_member_to_group!(
          %{membership_id: membership.id, group_id: group.id},
          tenant: forening.id,
          authorize?: false
        )

      assert :ok =
               Organizations.remove_member_from_group(mg,
                 tenant: forening.id,
                 actor: admin
               )
    end

    test "member groups loadable via membership" do
      forening = setup_forening()
      member = setup_member(forening)
      group = create_group(forening, %{name: "Loaded Group"})
      membership = get_membership(member, forening)

      Organizations.add_member_to_group!(
        %{membership_id: membership.id, group_id: group.id},
        tenant: forening.id,
        authorize?: false
      )

      loaded =
        Ash.load!(membership, [:groups], tenant: forening.id, authorize?: false)

      assert length(loaded.groups) == 1
      assert hd(loaded.groups).name == "Loaded Group"
    end
  end

  describe "Group policies" do
    test "regular member cannot create groups" do
      forening = setup_forening()
      member = setup_member(forening)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.create_group(
                 %{name: "Forbidden Group"},
                 tenant: forening.id,
                 actor: member
               )
    end

    test "regular member cannot update groups" do
      forening = setup_forening()
      member = setup_member(forening)
      group = create_group(forening)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.update_group(group, %{name: "Nope"},
                 tenant: forening.id,
                 actor: member
               )
    end

    test "regular member cannot destroy groups" do
      forening = setup_forening()
      member = setup_member(forening)
      group = create_group(forening)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.destroy_group(group,
                 tenant: forening.id,
                 actor: member
               )
    end

    test "regular member cannot assign members to groups" do
      forening = setup_forening()
      member = setup_member(forening)
      group = create_group(forening)
      membership = get_membership(member, forening)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organizations.add_member_to_group(
                 %{membership_id: membership.id, group_id: group.id},
                 tenant: forening.id,
                 actor: member
               )
    end

    test "unauthenticated user cannot list groups" do
      forening = setup_forening()
      create_group(forening)

      groups = Organizations.list_groups!(tenant: forening.id, actor: nil)
      assert groups == []
    end

    test "member of forening A cannot see forening B groups" do
      forening_a = setup_forening()
      forening_b = setup_forening()
      member_a = setup_member(forening_a)
      create_group(forening_b, %{name: "Secret Group"})

      groups = Organizations.list_groups!(tenant: forening_b.id, actor: member_a)
      assert groups == []
    end
  end
end
