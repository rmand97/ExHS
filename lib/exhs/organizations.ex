defmodule Exhs.Organizations do
  @moduledoc false
  use Ash.Domain, otp_app: :exhs, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Exhs.Organizations.Forening do
      define :create_forening, action: :create
      define :update_forening, action: :update
      define :archive_forening, action: :archive
      define :set_forening_stripe_account, action: :set_stripe_account
      define :get_forening_by_id, action: :get_by_id, args: [:id], get?: true
      define :get_forening_by_slug, action: :get_by_slug, args: [:slug], get?: true
      define :get_forening_by_subdomain, action: :get_by_subdomain, args: [:subdomain], get?: true

      define :get_forening_by_stripe_account_id,
        action: :get_by_stripe_account_id,
        args: [:stripe_account_id],
        get?: true

      define :list_foreninger, action: :read
    end

    resource Exhs.Organizations.Membership do
      define :invite_member, action: :invite, args: [:user_id]
      define :join_forening, action: :join
      define :activate_member, action: :activate
      define :deactivate_member, action: :deactivate
      define :set_member_role, action: :set_role
      define :leave_forening, action: :leave
      define :set_membership_stripe_customer, action: :set_stripe_customer

      define :get_membership_by_stripe_customer_id,
        action: :get_by_stripe_customer_id,
        args: [:stripe_customer_id],
        get?: true

      define :get_membership_by_id, action: :get_by_id, args: [:id], get?: true
      define :list_memberships, action: :read
      define :list_my_memberships, action: :my_memberships
      define :get_my_membership, action: :get_my_membership, args: [:id], get?: true
      define :list_all_memberships, action: :all_global
    end

    resource Exhs.Organizations.Group do
      define :create_group, action: :create
      define :update_group, action: :update
      define :destroy_group, action: :destroy
      define :get_group_by_id, action: :get_by_id, args: [:id], get?: true
      define :list_groups, action: :read
    end

    resource Exhs.Organizations.MemberGroup do
      define :add_member_to_group, action: :add
      define :remove_member_from_group, action: :remove
      define :list_member_groups, action: :read
    end
  end

  alias Exhs.Accounts
  alias Exhs.Organizations.InviteWorker

  @doc """
  Invite a person to the forening by email. Finds an existing user or creates a
  passwordless one, attaches an `:active` membership with the given role, and
  queues a magic-link sign-in email (`InviteWorker`).

  Admin authorization is enforced by the membership `:invite` action policy via
  the supplied `scope`. Returns `{:ok, membership}` or `{:error, reason}`.
  """
  def invite_member_by_email(email, attrs, scope) do
    email = email |> to_string() |> String.trim()

    with {:ok, user} <- ensure_user(email),
         {:ok, membership} <- invite_member(user.id, attrs, scope: scope) do
      InviteWorker.enqueue(email)
      {:ok, membership}
    end
  end

  @doc """
  Provision a brand-new forening and its first admin in one step. Intended for
  superadmin use: the `actor` must be a superadmin (enforced by the Forening
  `:create` policy's superadmin bypass). Creates the forening, finds or creates
  the admin user by email, attaches an `:admin` membership, and queues a
  magic-link sign-in email. Returns `{:ok, forening}` or `{:error, reason}`.
  """
  def provision_forening(attrs, admin_email, actor) do
    email = admin_email |> to_string() |> String.trim()

    with {:ok, forening} <- create_forening(attrs, actor: actor),
         scope = %Exhs.Scope{actor: actor, tenant: forening.id},
         {:ok, user} <- ensure_user(email),
         {:ok, _membership} <- invite_member(user.id, %{role: :admin}, scope: scope) do
      InviteWorker.enqueue(email)
      {:ok, forening}
    end
  end

  defp ensure_user(email) do
    case Accounts.get_user_by_email(email, authorize?: false) do
      {:ok, user} -> {:ok, user}
      _ -> Accounts.create_invited_user(email, authorize?: false)
    end
  end

  @doc """
  Remove a membership from a group by their ids, scoped to the tenant. Looks up
  the join row and destroys it. No-op (returns `:ok`) if not present.
  """
  def remove_member_from_group_by_keys(membership_id, group_id, scope) do
    case list_member_groups(scope: scope) do
      {:ok, joins} ->
        join =
          Enum.find(
            joins,
            &(&1.membership_id == membership_id and &1.group_id == group_id)
          )

        if join, do: remove_member_from_group(join, scope: scope), else: :ok

      error ->
        error
    end
  end
end
