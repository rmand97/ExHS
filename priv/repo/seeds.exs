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

defmodule Exhs.Seeds do
  @moduledoc false

  @test_email "test@exhs.dk"
  @test_password "password123"

  def run do
    Logger.info("Seeding…")

    user = upsert_test_user()
    # forening = upsert_default_forening(user)   # Task 4
    # _membership = upsert_membership(user, forening)   # Task 4
    # _event = upsert_sample_event(forening)     # Task 9
    # _product = upsert_sample_product(forening) # Task 10

    Logger.info("Seed complete. Sign in with #{user.email} / #{@test_password}")
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
end

Exhs.Seeds.run()
