defmodule Exhs.AdminMembersTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Organizations
  alias Exhs.Organizations.MemberFilter

  # Drains the test mailbox, returning true if any sent email targeted `addr`.
  defp emailed?(addr) do
    receive do
      {:email, %Swoosh.Email{to: to}} ->
        Enum.any?(to, fn {_name, a} -> a == addr end) or emailed?(addr)
    after
      0 -> false
    end
  end

  describe "invite_member_by_email/3" do
    setup do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      %{forening: forening, scope: scope(admin, forening)}
    end

    test "creates a passwordless user, an active membership, and sends a magic-link email",
         %{forening: forening, scope: scope} do
      email = "newcomer_#{System.unique_integer([:positive])}@example.com"

      assert {:ok, membership} =
               Organizations.invite_member_by_email(email, %{role: :member}, scope)

      assert membership.role == :member
      assert membership.status == :active

      assert {:ok, user} = Exhs.Accounts.get_user_by_email(email, authorize?: false)
      assert is_nil(user.hashed_password)
      assert membership.user_id == user.id

      # Oban runs inline in tests, so the InviteWorker has already sent the email.
      assert emailed?(email)

      members = Organizations.list_memberships!(tenant: forening.id, authorize?: false)
      assert Enum.any?(members, &(&1.id == membership.id))
    end

    test "reuses an existing user account", %{scope: scope} do
      existing = register_user!()

      assert {:ok, membership} =
               Organizations.invite_member_by_email(
                 to_string(existing.email),
                 %{role: :board},
                 scope
               )

      assert membership.user_id == existing.id
      assert membership.role == :board
    end

    test "re-inviting an already-invited person fails gracefully", %{scope: scope} do
      email = "dupe_#{System.unique_integer([:positive])}@example.com"
      assert {:ok, _} = Organizations.invite_member_by_email(email, %{role: :member}, scope)
      assert {:error, _} = Organizations.invite_member_by_email(email, %{role: :member}, scope)
    end
  end

  describe "invite authorization" do
    test "board role cannot invite" do
      forening = create_forening!()
      board = register_user!()
      invite_member!(forening, board, :board)

      assert {:error, _} =
               Organizations.invite_member_by_email(
                 "x_#{System.unique_integer([:positive])}@example.com",
                 %{role: :member},
                 scope(board, forening)
               )
    end
  end

  describe "group assignment" do
    setup do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      member = register_user!()
      membership = invite_member!(forening, member, :member)
      group = create_group!(forening)
      %{forening: forening, membership: membership, group: group, scope: scope(admin, forening)}
    end

    test "add is idempotent and remove deletes the join", %{
      membership: membership,
      group: group,
      scope: scope
    } do
      assert {:ok, _} =
               Organizations.add_member_to_group(
                 %{membership_id: membership.id, group_id: group.id},
                 scope: scope
               )

      # second add must not raise on the unique identity
      assert {:ok, _} =
               Organizations.add_member_to_group(
                 %{membership_id: membership.id, group_id: group.id},
                 scope: scope
               )

      joins = Organizations.list_member_groups!(scope: scope)
      assert Enum.count(joins, &(&1.membership_id == membership.id)) == 1

      assert :ok =
               Organizations.remove_member_from_group_by_keys(membership.id, group.id, scope)

      joins = Organizations.list_member_groups!(scope: scope)
      refute Enum.any?(joins, &(&1.membership_id == membership.id))
    end
  end

  describe "audit log" do
    setup do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      member = register_user!()
      membership = invite_member!(forening, member, :member)
      %{forening: forening, membership: membership, scope: scope(admin, forening)}
    end

    test "admin membership actions are recorded against the member's record", %{
      membership: membership,
      scope: scope
    } do
      Organizations.set_member_role(membership, %{role: :board}, scope: scope)
      {:ok, membership} = Organizations.get_membership_by_id(membership.id, scope: scope)
      Organizations.deactivate_member(membership, scope: scope)

      {:ok, events} = Exhs.Audit.list_events_for_record(membership.id, authorize?: false)
      actions = Enum.map(events, & &1.action)

      assert Enum.all?(events, &(&1.record_id == membership.id))
      assert :invite in actions
      assert :set_role in actions
      assert :deactivate in actions
    end

    test "group assignment is recorded", %{
      forening: forening,
      membership: membership,
      scope: scope
    } do
      group = create_group!(forening)

      Organizations.add_member_to_group(
        %{membership_id: membership.id, group_id: group.id},
        scope: scope
      )

      join = Organizations.list_member_groups!(scope: scope) |> hd()
      {:ok, events} = Exhs.Audit.list_events_for_record(join.id, authorize?: false)

      assert Enum.any?(events, &(&1.action == :add))
    end
  end

  describe "MemberFilter.apply/2" do
    setup do
      forening = create_forening!()

      alice = register_user!(email: "alice@example.com")
      bob = register_user!(email: "bob@example.com")
      m_alice = invite_member!(forening, alice, :admin)
      m_bob = invite_member!(forening, bob, :member)
      Organizations.deactivate_member!(m_bob, tenant: forening.id, authorize?: false)

      loaded =
        Organizations.list_memberships!(
          tenant: forening.id,
          load: [:user, :groups],
          authorize?: false
        )

      %{members: loaded, m_alice: m_alice}
    end

    test "filters by status", %{members: members} do
      result = MemberFilter.apply(members, %{status: "active"})
      assert length(result) == 1
      assert hd(result).status == :active
    end

    test "filters by role", %{members: members} do
      result = MemberFilter.apply(members, %{role: "admin"})
      assert length(result) == 1
      assert hd(result).role == :admin
    end

    test "filters by query against email", %{members: members} do
      result = MemberFilter.apply(members, %{q: "bob@"})
      assert length(result) == 1
      assert to_string(hd(result).user.email) == "bob@example.com"
    end

    test "empty filters return everything", %{members: members} do
      assert length(MemberFilter.apply(members, %{})) == 2
    end
  end
end
