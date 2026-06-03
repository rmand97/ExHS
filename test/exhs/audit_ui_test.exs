defmodule Exhs.AuditUiTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Audit
  alias Exhs.Organizations

  describe "list_my_activity/1" do
    test "returns events where user_id matches actor" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)

      Organizations.create_group!(%{name: "Test Group"},
        tenant: forening.id,
        actor: admin
      )

      {:ok, page} = Audit.list_my_activity(actor: admin)
      assert page.results != []
      assert Enum.all?(page.results, &(&1.user_id == admin.id))
    end

    test "returns empty list when user has no events" do
      user = register_user!()

      {:ok, page} = Audit.list_my_activity(actor: user)
      assert page.results == []
    end

    test "does NOT return events from other users" do
      forening = create_forening!()
      admin = register_user!()
      other = register_user!()
      invite_member!(forening, admin, :admin)
      invite_member!(forening, other, :admin)

      Organizations.create_group!(%{name: "Admin's Group"},
        tenant: forening.id,
        actor: admin
      )

      Organizations.create_group!(%{name: "Other's Group"},
        tenant: forening.id,
        actor: other
      )

      {:ok, admin_page} = Audit.list_my_activity(actor: admin)
      {:ok, other_page} = Audit.list_my_activity(actor: other)

      admin_record_ids = Enum.map(admin_page.results, & &1.record_id)
      other_record_ids = Enum.map(other_page.results, & &1.record_id)

      assert MapSet.disjoint?(MapSet.new(admin_record_ids), MapSet.new(other_record_ids))
    end
  end

  describe "policies" do
    test "superadmin can read all events globally" do
      superadmin = register_user!(superadmin: true)
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)

      Organizations.create_group!(%{name: "SA Test"}, tenant: forening.id, actor: admin)

      events = Ash.read!(Exhs.Audit.EventLog, actor: superadmin)
      assert events != []
    end

    test "regular user cannot use generic read action" do
      user = register_user!()

      events = Ash.read!(Exhs.Audit.EventLog, actor: user)
      assert events == []
    end

    test "unauthenticated actor is rejected" do
      assert {:error, %Ash.Error.Invalid{}} = Audit.list_my_activity(actor: nil)
    end
  end

  describe "tenant isolation" do
    setup do
      forening_a = create_forening!()
      forening_b = create_forening!()
      user_a = register_user!()
      user_b = register_user!()
      invite_member!(forening_a, user_a, :admin)
      invite_member!(forening_b, user_b, :admin)

      Organizations.create_group!(%{name: "Group A"},
        tenant: forening_a.id,
        actor: user_a
      )

      Organizations.create_group!(%{name: "Group B"},
        tenant: forening_b.id,
        actor: user_b
      )

      %{
        forening_a: forening_a,
        forening_b: forening_b,
        user_a: user_a,
        user_b: user_b
      }
    end

    test "user A only sees their own events", ctx do
      {:ok, page} = Audit.list_my_activity(actor: ctx.user_a)

      assert page.results != []
      assert Enum.all?(page.results, &(&1.user_id == ctx.user_a.id))
      refute Enum.any?(page.results, &(&1.user_id == ctx.user_b.id))
    end

    test "user B only sees their own events", ctx do
      {:ok, page} = Audit.list_my_activity(actor: ctx.user_b)

      assert page.results != []
      assert Enum.all?(page.results, &(&1.user_id == ctx.user_b.id))
      refute Enum.any?(page.results, &(&1.user_id == ctx.user_a.id))
    end

    test "user in both foreninger sees events from both, scoped to own user_id" do
      forening_a = create_forening!()
      forening_b = create_forening!()
      user = register_user!()
      invite_member!(forening_a, user, :admin)
      invite_member!(forening_b, user, :admin)

      group_a =
        Organizations.create_group!(%{name: "Group in A"},
          tenant: forening_a.id,
          actor: user
        )

      group_b =
        Organizations.create_group!(%{name: "Group in B"},
          tenant: forening_b.id,
          actor: user
        )

      {:ok, page} = Audit.list_my_activity(actor: user)

      record_ids = Enum.map(page.results, & &1.record_id)
      assert group_a.id in record_ids
      assert group_b.id in record_ids
      assert Enum.all?(page.results, &(&1.user_id == user.id))
    end

    test "events with user_id nil do not appear in any user's activity" do
      user = register_user!()
      create_forening!()

      {:ok, page} = Audit.list_my_activity(actor: user)
      refute Enum.any?(page.results, &is_nil(&1.user_id))
    end

    test "admin of forening A cannot see user B's events via my_activity", ctx do
      {:ok, page} = Audit.list_my_activity(actor: ctx.user_a)
      refute Enum.any?(page.results, &(&1.user_id == ctx.user_b.id))
    end
  end
end
