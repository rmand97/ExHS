defmodule Exhs.Organizations do
  @moduledoc false
  use Ash.Domain, otp_app: :exhs, extensions: [AshAdmin.Domain, AshPaperTrail.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions? true
  end

  resources do
    resource Exhs.Organizations.Forening do
      define :create_forening, action: :create
      define :update_forening, action: :update
      define :archive_forening, action: :archive
      define :get_forening_by_id, action: :get_by_id, args: [:id], get?: true
      define :get_forening_by_slug, action: :get_by_slug, args: [:slug], get?: true
      define :get_forening_by_subdomain, action: :get_by_subdomain, args: [:subdomain], get?: true
      define :list_foreninger, action: :read
    end

    resource Exhs.Organizations.Membership do
      define :invite_member, action: :invite, args: [:user_id]
      define :join_forening, action: :join
      define :activate_member, action: :activate
      define :deactivate_member, action: :deactivate
      define :set_member_role, action: :set_role
      define :leave_forening, action: :leave
      define :list_memberships, action: :read
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
