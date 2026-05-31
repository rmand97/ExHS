# Seed data for local development.
#
# Run directly:    mix run priv/repo/seeds.exs
# Run via setup:   mix setup        # also calls this script
# Run via reset:   mix ecto.reset   # ditto
#
# Every entry below must be idempotent — look up first, create only if missing —
# so re-running the seed is always safe. As new features land, append a new
# section here (Foreninger, Events, Memberships, …) so a developer can go from
# `git clone` to a fully populated app with one command.

require Ash.Query
require Logger

alias Exhs.Accounts.User
alias Exhs.Billing
alias Exhs.Billing.{Payment, Subscription}
alias Exhs.Events
alias Exhs.Events.{Event, TicketType, Registration}
alias Exhs.Organizations
alias Exhs.Organizations.Forening
alias Exhs.Organizations.Group
alias Exhs.Organizations.Membership

defmodule Exhs.Seeds do
  @moduledoc false

  @test_email "test@exhs.dk"
  @test_password "password123"

  def run do
    Logger.info("Seeding…")

    user = upsert_test_user()
    forening = upsert_default_forening()
    membership = upsert_membership(user, forening, :admin)
    upsert_groups(forening)
    upsert_sample_members(forening)
    upsert_sample_billing(forening, membership)
    upsert_sample_events(forening, membership)

    second = upsert_second_forening()
    second_membership = upsert_membership(user, second, :member)
    upsert_sport_events(second, second_membership)

    seed_audit_activity(user, forening, membership, second, second_membership)

    Logger.info(
      "Seed complete. Sign in with #{user.email} / #{@test_password}\n" <>
        "  Demo:   #{forening.subdomain}.lvh.me\n" <>
        "  Sport:  #{second.subdomain}.lvh.me\n" <>
        "  Dashboard: lvh.me:4000/dashboard"
    )
  end

  defp upsert_test_user do
    existing =
      User
      |> Ash.Query.filter(email == ^@test_email)
      |> Ash.read_one!(authorize?: false)

    case existing do
      %User{} = user ->
        Logger.info("Test user already exists: #{user.email}")
        ensure_profile(user)

      nil ->
        {:ok, user} =
          User
          |> Ash.Changeset.for_create(:register_with_password, %{
            email: @test_email,
            password: @test_password,
            password_confirmation: @test_password
          })
          |> Ash.create(authorize?: false)

        Logger.info("Created test user: #{user.email}")
        ensure_profile(user)
    end
  end

  defp ensure_profile(user) do
    if is_nil(user.first_name) do
      {:ok, user} =
        Exhs.Accounts.update_profile(
          user,
          %{
            first_name: "Test",
            last_name: "Admin",
            phone: "+4700000000",
            address_line_1: "Testveien 1",
            postal_code: "0001",
            city: "Oslo"
          },
          authorize?: false
        )

      Logger.info("Populated test user profile")
      user
    else
      user
    end
  end

  defp upsert_default_forening do
    existing =
      Forening
      |> Ash.Query.filter(slug == "demo")
      |> Ash.read_one!(authorize?: false)

    case existing do
      %Forening{} = f ->
        Logger.info("Forening already exists: #{f.name}")
        ensure_forening_branding(f)

      nil ->
        f =
          Organizations.create_forening!(
            %{
              name: "Demo Forening",
              slug: "demo",
              subdomain: "demo",
              kontingent_amount_cents: 30_000,
              kontingent_currency: "DKK",
              branding: %{
                "tagline" => "Et aktivt fællesskab for alle",
                "about" =>
                  "Demo Forening er en forening for alle, der brænder for fællesskab, events og sjove aktiviteter. Vi holder møder, sociale arrangementer og meget mere."
              }
            },
            authorize?: false
          )

        Logger.info("Created forening: #{f.name}")
        f
    end
  end

  defp ensure_forening_branding(%Forening{branding: branding} = f)
       when is_map(branding) and map_size(branding) > 0,
       do: f

  defp ensure_forening_branding(forening) do
    Organizations.update_forening!(
      forening,
      %{
        branding: %{
          "tagline" => "Et aktivt fællesskab for alle",
          "about" =>
            "Demo Forening er en forening for alle, der brænder for fællesskab, events og sjove aktiviteter."
        }
      },
      authorize?: false
    )
    |> tap(fn _ -> Logger.info("Added branding to #{forening.name}") end)
  end

  defp upsert_second_forening do
    existing =
      Forening
      |> Ash.Query.filter(slug == "sport")
      |> Ash.read_one!(authorize?: false)

    case existing do
      %Forening{} = f ->
        Logger.info("Second forening already exists: #{f.name}")
        f

      nil ->
        f =
          Organizations.create_forening!(
            %{
              name: "Sportsklubben",
              slug: "sport",
              subdomain: "sport",
              kontingent_amount_cents: 50_000,
              kontingent_currency: "DKK",
              branding: %{
                "tagline" => "Motion og fællesskab",
                "about" =>
                  "Sportsklubben samler alle, der elsker motion — fra løb og fodbold til yoga og badminton."
              }
            },
            authorize?: false
          )

        Logger.info("Created second forening: #{f.name}")
        f
    end
  end

  defp upsert_membership(user, forening, role \\ :admin) do
    existing =
      Membership
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read_one!(tenant: forening.id, authorize?: false)

    case existing do
      %Membership{} = m ->
        Logger.info("Membership already exists for #{user.email} in #{forening.name}")
        m

      nil ->
        m =
          Organizations.invite_member!(user.id, %{role: role},
            tenant: forening.id,
            authorize?: false
          )

        Logger.info("Created #{role} membership for #{user.email} in #{forening.name}")
        m
    end
  end

  @seed_groups [
    %{name: "Bestyrelse", color: "#3b82f6", description: "Board members"},
    %{name: "Frivillige", color: "#22c55e", description: "Volunteers"},
    %{name: "Ungdom", color: "#f59e0b", description: "Youth members under 25"}
  ]

  defp upsert_groups(forening) do
    existing =
      Group
      |> Ash.read!(tenant: forening.id, authorize?: false)
      |> MapSet.new(& &1.name)

    Enum.each(@seed_groups, fn attrs ->
      if MapSet.member?(existing, attrs.name) do
        Logger.info("Group already exists: #{attrs.name}")
      else
        Organizations.create_group!(attrs, tenant: forening.id, authorize?: false)
        Logger.info("Created group: #{attrs.name}")
      end
    end)
  end

  # A handful of members so the admin Members list has something to show:
  # varied roles, one deactivated, some assigned to groups.
  @sample_members [
    %{
      email: "frida@demo.dk",
      first: "Frida",
      last: "Hansen",
      role: :board,
      status: :active,
      group: "Bestyrelse"
    },
    %{
      email: "jonas@demo.dk",
      first: "Jonas",
      last: "Berg",
      role: :member,
      status: :active,
      group: "Frivillige"
    },
    %{
      email: "mette@demo.dk",
      first: "Mette",
      last: "Sørensen",
      role: :member,
      status: :active,
      group: "Ungdom"
    },
    %{
      email: "lars@demo.dk",
      first: "Lars",
      last: "Nielsen",
      role: :member,
      status: :inactive,
      group: nil
    },
    %{
      email: "sofie@demo.dk",
      first: "Sofie",
      last: "Andersen",
      role: :member,
      status: :active,
      group: nil
    }
  ]

  defp upsert_sample_members(forening) do
    groups =
      Group
      |> Ash.read!(tenant: forening.id, authorize?: false)
      |> Map.new(&{&1.name, &1})

    Enum.each(@sample_members, fn attrs ->
      member = upsert_member_user(attrs)
      membership = upsert_membership(member, forening, attrs.role)
      ensure_member_status(membership, attrs.status, forening)
      ensure_member_group(membership, groups[attrs.group], forening)
    end)
  end

  defp upsert_member_user(attrs) do
    existing =
      User
      |> Ash.Query.filter(email == ^attrs.email)
      |> Ash.read_one!(authorize?: false)

    case existing do
      %User{} = u ->
        u

      nil ->
        {:ok, user} =
          User
          |> Ash.Changeset.for_create(:register_with_password, %{
            email: attrs.email,
            password: @test_password,
            password_confirmation: @test_password
          })
          |> Ash.create(authorize?: false)

        {:ok, user} =
          Exhs.Accounts.update_profile(
            user,
            %{first_name: attrs.first, last_name: attrs.last},
            authorize?: false
          )

        Logger.info("Created sample member: #{user.email}")
        user
    end
  end

  defp ensure_member_status(membership, :inactive, forening) do
    if membership.status != :inactive do
      Organizations.deactivate_member!(membership, tenant: forening.id, authorize?: false)
    end
  end

  defp ensure_member_status(_membership, _status, _forening), do: :ok

  defp ensure_member_group(_membership, nil, _forening), do: :ok

  defp ensure_member_group(membership, group, forening) do
    Organizations.add_member_to_group!(
      %{membership_id: membership.id, group_id: group.id},
      tenant: forening.id,
      authorize?: false
    )
  end

  # Seeds use placeholder Stripe IDs — no Stripe API calls happen here. They
  # exist so a fresh clone shows what a member's billing state looks like.
  @seed_stripe_account_id "acct_demo_seed"
  @seed_subscription_id "sub_demo_seed"
  @seed_payment_intent_id "pi_demo_seed"
  @seed_customer_id "cus_demo_seed"

  defp upsert_sample_billing(forening, membership) do
    forening = ensure_seed_connect_account(forening)
    _membership = ensure_seed_customer(membership, forening)
    subscription = upsert_seed_subscription(forening, membership)
    upsert_seed_payment(forening, membership, subscription)
  end

  defp ensure_seed_connect_account(%Forening{stripe_account_id: id} = f) when is_binary(id), do: f

  defp ensure_seed_connect_account(forening) do
    Organizations.set_forening_stripe_account!(
      forening,
      %{stripe_account_id: @seed_stripe_account_id, stripe_account_status: :active},
      authorize?: false
    )
    |> tap(fn _ -> Logger.info("Seeded Connect account on #{forening.name}") end)
  end

  defp ensure_seed_customer(%Membership{stripe_customer_id: id} = m, _f) when is_binary(id), do: m

  defp ensure_seed_customer(membership, forening) do
    Organizations.set_membership_stripe_customer!(
      membership,
      %{stripe_customer_id: @seed_customer_id},
      tenant: forening.id,
      authorize?: false
    )
    |> tap(fn _ -> Logger.info("Seeded Stripe customer on test membership") end)
  end

  defp upsert_seed_subscription(forening, membership) do
    existing =
      Subscription
      |> Ash.Query.filter(stripe_subscription_id == ^@seed_subscription_id)
      |> Ash.read_one!(tenant: forening.id, authorize?: false)

    case existing do
      %Subscription{} = s ->
        Logger.info("Subscription already exists")
        s

      nil ->
        period_start = DateTime.utc_now()
        period_end = DateTime.add(period_start, 365, :day)

        s =
          Billing.create_subscription!(
            %{
              membership_id: membership.id,
              stripe_subscription_id: @seed_subscription_id,
              stripe_customer_id: @seed_customer_id,
              status: :active,
              current_period_start: period_start,
              current_period_end: period_end,
              cancel_at_period_end: false
            },
            tenant: forening.id,
            authorize?: false
          )

        Logger.info("Created seed subscription")
        s
    end
  end

  defp upsert_seed_payment(forening, membership, _subscription) do
    existing =
      Payment
      |> Ash.Query.filter(stripe_payment_intent_id == ^@seed_payment_intent_id)
      |> Ash.read_one!(tenant: forening.id, authorize?: false)

    case existing do
      %Payment{} = p ->
        Logger.info("Payment already exists")
        p

      nil ->
        p =
          Billing.record_payment!(
            %{
              payable_type: :subscription,
              payable_id: membership.id,
              amount_cents: 30_000,
              currency: "DKK",
              status: :succeeded,
              stripe_payment_intent_id: @seed_payment_intent_id,
              description: "Kontingent — seed",
              paid_at: DateTime.utc_now()
            },
            tenant: forening.id,
            authorize?: false
          )

        Logger.info("Created seed payment")
        p
    end
  end

  defp upsert_sample_events(forening, membership) do
    event = upsert_seed_event(forening, "Generalforsamling 2026", true)
    open_event = upsert_seed_event(forening, "Åbent Hus", false)
    upsert_seed_ticket_types(forening, event, open_event)
    if membership, do: upsert_seed_registration(forening, event, membership)
  end

  defp upsert_seed_event(forening, title, membership_required) do
    existing =
      Event
      |> Ash.Query.filter(title == ^title)
      |> Ash.read_one!(tenant: forening.id, authorize?: false)

    case existing do
      %Event{} = e ->
        Logger.info("Event already exists: #{e.title}")
        e

      nil ->
        e =
          Events.create_event!(
            %{
              title: title,
              description: "Seed event — #{title}",
              location: "Foreningshuset",
              starts_at: DateTime.add(DateTime.utc_now(), 30, :day),
              ends_at: DateTime.add(DateTime.utc_now(), 30 * 86_400 + 7200, :second),
              membership_required: membership_required
            },
            tenant: forening.id,
            authorize?: false
          )

        Events.publish_event!(e, authorize?: false)
        |> tap(fn _ -> Logger.info("Created and published event: #{title}") end)
    end
  end

  defp upsert_seed_ticket_types(forening, event, open_event) do
    ensure_ticket_type(forening, event, "Medlem", 0, nil)
    ensure_ticket_type(forening, event, "VIP", 15_000, 20)
    ensure_ticket_type(forening, open_event, "Gratis", 0, nil)
  end

  defp ensure_ticket_type(forening, event, name, price, capacity) do
    existing =
      TicketType
      |> Ash.Query.filter(event_id == ^event.id and name == ^name)
      |> Ash.read_one!(tenant: forening.id, authorize?: false)

    case existing do
      %TicketType{} ->
        Logger.info("Ticket type already exists: #{name}")

      nil ->
        Events.create_ticket_type!(
          %{event_id: event.id, name: name, price_cents: price, capacity: capacity},
          tenant: forening.id,
          authorize?: false
        )

        Logger.info("Created ticket type: #{name} for #{event.title}")
    end
  end

  defp upsert_seed_registration(forening, event, membership, ticket_name \\ "Medlem") do
    ticket_type =
      TicketType
      |> Ash.Query.filter(event_id == ^event.id and name == ^ticket_name)
      |> Ash.read_one!(tenant: forening.id, authorize?: false)

    existing =
      Registration
      |> Ash.Query.filter(ticket_type_id == ^ticket_type.id and membership_id == ^membership.id)
      |> Ash.read_one!(tenant: forening.id, authorize?: false)

    case existing do
      %Registration{} ->
        Logger.info("Registration already exists")

      nil ->
        Events.register_for_event!(
          %{ticket_type_id: ticket_type.id, membership_id: membership.id},
          tenant: forening.id,
          authorize?: false
        )

        Logger.info("Created seed registration for #{event.title}")
    end
  end

  defp seed_audit_activity(user, forening, membership, second_forening, second_membership) do
    alias Exhs.Audit.EventLog

    has_user_events =
      EventLog
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.read!(authorize?: false)
      |> length()

    if has_user_events >= 25 do
      Logger.info("Audit activity already seeded (#{has_user_events} events)")
    else
      Logger.info("Seeding audit activity as #{user.email} (clearing partial data)…")

      Exhs.Repo.query!("DELETE FROM audit_events WHERE user_id = $1", [
        Ecto.UUID.dump!(user.id)
      ])

      Exhs.Repo.query!(
        "DELETE FROM groups WHERE name LIKE 'Udvalg %' OR name LIKE 'Sporthold %' OR name = 'Hovedudvalget'"
      )

      Exhs.Repo.query!(~s[
        DELETE FROM event_registrations WHERE ticket_type_id IN
          (SELECT id FROM event_ticket_types WHERE event_id IN
            (SELECT id FROM events WHERE title IN ('Admin-oprettet Event', 'Løbetræning')))
      ])

      Exhs.Repo.query!(~s[
        DELETE FROM event_ticket_types WHERE event_id IN
          (SELECT id FROM events WHERE title IN ('Admin-oprettet Event', 'Løbetræning'))
      ])

      Exhs.Repo.query!(
        "DELETE FROM events WHERE title IN ('Admin-oprettet Event', 'Løbetræning')"
      )

      for i <- 1..8 do
        Organizations.create_group!(
          %{
            name: "Udvalg #{i}",
            color: "##{String.pad_leading(Integer.to_string(i * 30, 16), 6, "0")}"
          },
          tenant: forening.id,
          actor: user
        )
      end

      for i <- 1..4 do
        Organizations.create_group!(
          %{name: "Sporthold #{i}", color: "#e11d48"},
          tenant: second_forening.id,
          authorize?: false,
          actor: user
        )
      end

      extra_user_1 = upsert_extra_user("medlem1@exhs.dk", "Marie", "Jensen")
      extra_user_2 = upsert_extra_user("medlem2@exhs.dk", "Lars", "Nielsen")

      m1 = upsert_membership(extra_user_1, forening, :member)
      m2 = upsert_membership(extra_user_2, forening, :member)

      Organizations.set_member_role!(m1, %{role: :board}, tenant: forening.id, actor: user)
      Organizations.set_member_role!(m2, %{role: :board}, tenant: forening.id, actor: user)
      Organizations.set_member_role!(m2, %{role: :member}, tenant: forening.id, actor: user)

      groups = Group |> Ash.read!(tenant: forening.id, authorize?: false)

      if g = Enum.find(groups, &(&1.name == "Udvalg 1")) do
        Organizations.update_group!(g, %{name: "Hovedudvalget"}, tenant: forening.id, actor: user)
      end

      if g = Enum.find(groups, &(&1.name == "Udvalg 8")) do
        Organizations.destroy_group!(g, tenant: forening.id, actor: user)
      end

      event =
        Events.create_event!(
          %{
            title: "Admin-oprettet Event",
            description: "Oprettet via seed som test-bruger",
            location: "Foreningslokalet",
            starts_at: DateTime.add(DateTime.utc_now(), 14, :day)
          },
          tenant: forening.id,
          actor: user
        )

      Events.publish_event!(event, actor: user)

      tt =
        Events.create_ticket_type!(
          %{event_id: event.id, name: "Standard", price_cents: 0},
          tenant: forening.id,
          actor: user
        )

      Events.register_for_event!(
        %{ticket_type_id: tt.id, membership_id: membership.id},
        tenant: forening.id,
        actor: user
      )

      sport_event =
        Events.create_event!(
          %{
            title: "Løbetræning",
            description: "Tirsdags-løb",
            location: "Fælledparken",
            starts_at: DateTime.add(DateTime.utc_now(), 7, :day)
          },
          tenant: second_forening.id,
          authorize?: false,
          actor: user
        )

      Events.publish_event!(sport_event, authorize?: false, actor: user)

      stt =
        Events.create_ticket_type!(
          %{event_id: sport_event.id, name: "Deltager", price_cents: 0},
          tenant: second_forening.id,
          authorize?: false,
          actor: user
        )

      Events.register_for_event!(
        %{ticket_type_id: stt.id, membership_id: second_membership.id},
        tenant: second_forening.id,
        authorize?: false,
        actor: user
      )

      count =
        EventLog
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read!(authorize?: false)
        |> length()

      Logger.info("Seeded #{count} audit events for #{user.email}")
    end
  end

  defp upsert_extra_user(email, first, last) do
    existing =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    case existing do
      %User{} = u ->
        u

      nil ->
        {:ok, u} =
          User
          |> Ash.Changeset.for_create(:register_with_password, %{
            email: email,
            password: @test_password,
            password_confirmation: @test_password
          })
          |> Ash.create(authorize?: false)

        {:ok, u} =
          Exhs.Accounts.update_profile(u, %{first_name: first, last_name: last},
            authorize?: false
          )

        Logger.info("Created extra user: #{email}")
        u
    end
  end

  defp upsert_sport_events(forening, membership) do
    event = upsert_seed_event(forening, "Fodboldturnering 2026", false)
    yoga = upsert_seed_event(forening, "Yoga i Parken", false)
    ensure_ticket_type(forening, event, "Deltager", 5_000, 40)
    ensure_ticket_type(forening, yoga, "Gratis", 0, nil)
    if membership, do: upsert_seed_registration(forening, event, membership, "Deltager")
  end
end

Exhs.Seeds.run()
