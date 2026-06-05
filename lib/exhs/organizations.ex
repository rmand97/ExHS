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

      define :list_memberships, action: :read
      define :list_my_memberships, action: :my_memberships
      define :get_my_membership, action: :get_my_membership, args: [:id], get?: true
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
end
