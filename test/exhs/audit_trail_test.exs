defmodule Exhs.AuditTrailTest do
  use Exhs.DataCase, async: true

  alias Exhs.Accounts
  alias Exhs.Organizations

  defp unique_email, do: "user-#{System.unique_integer([:positive])}@example.com"

  defp setup_forening do
    Organizations.create_forening!(
      %{
        name: "Audit Forening",
        slug: "audit-#{System.unique_integer([:positive])}",
        subdomain: "audit#{System.unique_integer([:positive])}"
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

    Organizations.join_forening!(%{}, tenant: forening.id, actor: user)
    user
  end

  describe "version creation" do
    test "updating a membership creates a version record" do
      forening = setup_forening()
      admin = setup_admin(forening)
      member = setup_member(forening)

      membership =
        Organizations.list_memberships!(tenant: forening.id, authorize?: false)
        |> Enum.find(&(&1.user_id == member.id))

      Organizations.set_member_role!(membership, %{role: :board},
        tenant: forening.id,
        actor: admin
      )

      versions =
        Ash.read!(Exhs.Organizations.Membership.Version,
          tenant: forening.id,
          authorize?: false
        )

      assert versions != []
      latest = List.last(versions)
      assert latest.version_action_name == :set_role
      assert latest.version_source_id == membership.id
    end

    test "creating a group creates a version record" do
      forening = setup_forening()
      admin = setup_admin(forening)

      group =
        Organizations.create_group!(%{name: "Versioned Group"},
          tenant: forening.id,
          actor: admin
        )

      versions =
        Ash.read!(Exhs.Organizations.Group.Version,
          tenant: forening.id,
          authorize?: false
        )

      assert length(versions) == 1
      version = hd(versions)
      assert version.version_action_name == :create
      assert version.version_source_id == group.id
    end

    test "updating a forening creates a version record" do
      forening = setup_forening()
      admin = setup_admin(forening)

      Organizations.update_forening!(forening, %{name: "New Name"},
        actor: admin,
        tenant: forening.id
      )

      versions =
        Ash.read!(Exhs.Organizations.Forening.Version, authorize?: false)
        |> Enum.filter(&(&1.version_source_id == forening.id))

      assert versions != []
      latest = List.last(versions)
      assert latest.version_action_name == :update
    end
  end

  describe "actor tracking" do
    test "version records the actor who made the change" do
      forening = setup_forening()
      admin = setup_admin(forening)

      Organizations.create_group!(%{name: "Actor Test"},
        tenant: forening.id,
        actor: admin
      )

      versions =
        Ash.read!(Exhs.Organizations.Group.Version,
          tenant: forening.id,
          authorize?: false
        )

      assert hd(versions).user_id == admin.id
    end
  end

  describe "changes_only mode" do
    test "version only stores changed fields" do
      forening = setup_forening()
      admin = setup_admin(forening)
      group = create_group(forening)

      Organizations.update_group!(group, %{name: "Only Name Changed"},
        tenant: forening.id,
        actor: admin
      )

      versions =
        Ash.read!(Exhs.Organizations.Group.Version,
          tenant: forening.id,
          authorize?: false
        )

      update_version = Enum.find(versions, &(&1.version_action_name == :update))
      assert Map.has_key?(update_version.changes, "name")
      refute Map.has_key?(update_version.changes, "color")
      refute Map.has_key?(update_version.changes, "description")
    end
  end

  describe "tenant isolation" do
    test "version records are scoped to forening" do
      forening_a = setup_forening()
      forening_b = setup_forening()
      setup_admin(forening_a)
      setup_admin(forening_b)

      create_group(forening_a)
      create_group(forening_b)

      versions_a =
        Ash.read!(Exhs.Organizations.Group.Version,
          tenant: forening_a.id,
          authorize?: false
        )

      versions_b =
        Ash.read!(Exhs.Organizations.Group.Version,
          tenant: forening_b.id,
          authorize?: false
        )

      assert Enum.all?(versions_a, &(&1.forening_id == forening_a.id))
      assert Enum.all?(versions_b, &(&1.forening_id == forening_b.id))
      assert versions_a != []
      assert versions_b != []
    end
  end

  describe "sensitive fields" do
    test "hashed_password is not stored in user version changes" do
      forening = setup_forening()
      admin = setup_admin(forening)
      member = setup_member(forening)

      membership =
        Organizations.list_memberships!(tenant: forening.id, authorize?: false)
        |> Enum.find(&(&1.user_id == member.id))

      Organizations.set_member_role!(membership, %{role: :board},
        tenant: forening.id,
        actor: admin
      )

      versions =
        Ash.read!(Exhs.Organizations.Membership.Version,
          tenant: forening.id,
          authorize?: false
        )

      Enum.each(versions, fn v ->
        refute Map.has_key?(v.changes, "hashed_password")
      end)
    end
  end

  defp create_group(forening) do
    Organizations.create_group!(
      %{name: "Group #{System.unique_integer([:positive])}", color: "#aabbcc"},
      tenant: forening.id,
      authorize?: false
    )
  end
end
