defmodule Exhs.AuditTrailTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Audit.EventLog
  alias Exhs.Organizations

  require Ash.Query

  defp events_for(record_id) do
    EventLog
    |> Ash.Query.filter(record_id == ^record_id)
    |> Ash.read!(authorize?: false)
  end

  describe "event creation" do
    test "updating a membership creates an event" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      member = register_user!()
      membership = invite_member!(forening, member)

      Organizations.set_member_role!(membership, %{role: :board},
        tenant: forening.id,
        actor: admin
      )

      events = events_for(membership.id)
      assert events != []
      latest = List.last(events)
      assert latest.action == :set_role
      assert latest.record_id == membership.id
    end

    test "creating a group creates an event" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)

      group =
        Organizations.create_group!(%{name: "Versioned Group"},
          tenant: forening.id,
          actor: admin
        )

      events = events_for(group.id)
      assert length(events) == 1
      event = hd(events)
      assert event.action == :create
      assert event.record_id == group.id
    end

    test "updating a forening creates an event" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)

      Organizations.update_forening!(forening, %{name: "New Name"},
        actor: admin,
        tenant: forening.id
      )

      events = events_for(forening.id)
      update_events = Enum.filter(events, &(&1.action == :update))
      assert update_events != []
    end
  end

  describe "actor tracking" do
    test "event records the actor who made the change" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)

      group =
        Organizations.create_group!(%{name: "Actor Test"},
          tenant: forening.id,
          actor: admin
        )

      events = events_for(group.id)
      assert hd(events).user_id == admin.id
    end
  end

  describe "data tracking" do
    test "event stores input data" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      group = create_group!(forening)

      Organizations.update_group!(group, %{name: "Only Name Changed"},
        tenant: forening.id,
        actor: admin
      )

      events = events_for(group.id)
      update_event = Enum.find(events, &(&1.action == :update))
      assert update_event.data["name"] == "Only Name Changed"
    end
  end

  describe "tenant isolation" do
    test "events from different foreninger use distinct record IDs" do
      forening_a = create_forening!()
      forening_b = create_forening!()

      group_a = create_group!(forening_a)
      group_b = create_group!(forening_b)

      events_a = events_for(group_a.id)
      events_b = events_for(group_b.id)

      assert events_a != []
      assert events_b != []
      assert Enum.all?(events_a, &(&1.record_id == group_a.id))
      assert Enum.all?(events_b, &(&1.record_id == group_b.id))
    end
  end

  describe "sensitive fields" do
    test "sensitive fields not stored in event data" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      member = register_user!()
      membership = invite_member!(forening, member)

      Organizations.set_member_role!(membership, %{role: :board},
        tenant: forening.id,
        actor: admin
      )

      events = events_for(membership.id)

      Enum.each(events, fn e ->
        refute Map.has_key?(e.data, "hashed_password")
        refute Map.has_key?(e.changed_attributes, "hashed_password")
      end)
    end
  end

  describe "destroy tracking" do
    test "destroying a group creates an event" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      group = create_group!(forening)

      Organizations.destroy_group!(group, tenant: forening.id, actor: admin)

      events = events_for(group.id)
      destroy_event = Enum.find(events, &(&1.action_type == :destroy))
      assert destroy_event != nil
    end
  end
end
