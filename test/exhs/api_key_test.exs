defmodule Exhs.ApiKeyTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Accounts.ApiKey

  describe "API key lifecycle" do
    test "creates an API key with hash and expiry" do
      user = register_user!()

      {:ok, api_key} =
        ApiKey
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 30, :day)
        })
        |> Ash.create(authorize?: false)

      assert api_key.id
      assert api_key.api_key_hash
      assert api_key.expires_at
      assert api_key.user_id == user.id
    end

    test "sign_in_with_api_key authenticates a valid key" do
      user = register_user!()

      {:ok, api_key} =
        ApiKey
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 30, :day)
        })
        |> Ash.create(authorize?: false)

      raw_key = api_key.__metadata__[:plaintext_api_key]

      {:ok, [authenticated]} =
        Exhs.Accounts.User
        |> Ash.Query.for_read(:sign_in_with_api_key, %{api_key: raw_key})
        |> Ash.read(authorize?: false)

      assert authenticated.id == user.id
    end

    test "expired key does not authenticate" do
      user = register_user!()

      {:ok, api_key} =
        ApiKey
        |> Ash.Changeset.for_create(:create, %{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), -1, :day)
        })
        |> Ash.create(authorize?: false)

      raw_key = api_key.__metadata__[:plaintext_api_key]

      result =
        Exhs.Accounts.User
        |> Ash.Query.for_read(:sign_in_with_api_key, %{api_key: raw_key})
        |> Ash.read(authorize?: false)

      case result do
        {:ok, []} -> assert true
        {:error, _} -> assert true
      end
    end

    test "invalid key does not authenticate" do
      result =
        Exhs.Accounts.User
        |> Ash.Query.for_read(:sign_in_with_api_key, %{api_key: "exhs_bogus_key"})
        |> Ash.read(authorize?: false)

      case result do
        {:ok, []} -> assert true
        {:error, _} -> assert true
      end
    end
  end
end
