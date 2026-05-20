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
    upsert_membership(user, forening)
    upsert_groups(forening)
    # _event = upsert_sample_event(forening)     # Task 9
    # _product = upsert_sample_product(forening) # Task 10

    Logger.info(
      "Seed complete. Sign in with #{user.email} / #{@test_password} — forening at #{forening.subdomain}.lvh.me"
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
        f

      nil ->
        f =
          Organizations.create_forening!(
            %{
              name: "Demo Forening",
              slug: "demo",
              subdomain: "demo",
              kontingent_amount_cents: 30_000,
              kontingent_currency: "DKK"
            },
            authorize?: false
          )

        Logger.info("Created forening: #{f.name}")
        f
    end
  end

  defp upsert_membership(user, forening) do
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
          Organizations.invite_member!(user.id, %{role: :admin},
            tenant: forening.id,
            authorize?: false
          )

        Logger.info("Created admin membership for #{user.email} in #{forening.name}")
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
end

Exhs.Seeds.run()
