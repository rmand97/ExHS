defmodule Exhs.AccountsTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders
  import Swoosh.TestAssertions

  alias Exhs.Accounts

  describe "register_with_password" do
    test "creates a user with valid inputs" do
      user = register_user!()

      assert user.id
      assert user.email
    end

    test "rejects mismatched password confirmation" do
      assert_raise Ash.Error.Invalid, fn ->
        Accounts.register_with_password!(
          "mismatch@example.com",
          "password123",
          "different123",
          authorize?: false
        )
      end
    end

    test "rejects duplicate email" do
      user = register_user!()

      assert_raise Ash.Error.Invalid, fn ->
        Accounts.register_with_password!(
          to_string(user.email),
          "password123",
          "password123",
          authorize?: false
        )
      end
    end

    test "rejects short password" do
      assert_raise Ash.Error.Invalid, fn ->
        Accounts.register_with_password!(
          "short@example.com",
          "short",
          "short",
          authorize?: false
        )
      end
    end
  end

  describe "sign_in_with_password" do
    test "succeeds with correct credentials" do
      user = register_user!(email: "login@example.com")

      assert {:ok, signed_in} =
               Accounts.sign_in_with_password("login@example.com", "password123",
                 authorize?: false
               )

      assert signed_in.id == user.id
    end

    test "fails with wrong password" do
      register_user!(email: "wrong@example.com")

      assert {:error, _} =
               Accounts.sign_in_with_password("wrong@example.com", "badpassword",
                 authorize?: false
               )
    end

    test "fails with non-existent email" do
      assert {:error, _} =
               Accounts.sign_in_with_password("nobody@example.com", "password123",
                 authorize?: false
               )
    end
  end

  describe "get_user_by_id" do
    test "returns the user" do
      user = register_user!()

      assert Accounts.get_user_by_id!(user.id, authorize?: false).id == user.id
    end

    test "raises for non-existent id" do
      assert_raise Ash.Error.Invalid, fn ->
        Accounts.get_user_by_id!(Ash.UUID.generate(), authorize?: false)
      end
    end
  end

  describe "get_user_by_email" do
    test "returns the user" do
      user = register_user!()

      assert Accounts.get_user_by_email!(user.email, authorize?: false).id == user.id
    end
  end

  describe "update_profile" do
    test "updates profile fields" do
      user = register_user!()

      updated =
        Accounts.update_profile!(
          user,
          %{first_name: "Ola", last_name: "Nordmann", phone: "+4712345678", city: "Oslo"},
          authorize?: false
        )

      assert updated.first_name == "Ola"
      assert updated.last_name == "Nordmann"
      assert updated.phone == "+4712345678"
      assert updated.city == "Oslo"
    end

    test "updates address fields" do
      user = register_user!()

      updated =
        Accounts.update_profile!(
          user,
          %{
            address_line_1: "Storgata 1",
            address_line_2: "Leilighet 3",
            postal_code: "0001",
            city: "Oslo"
          },
          authorize?: false
        )

      assert updated.address_line_1 == "Storgata 1"
      assert updated.postal_code == "0001"
    end
  end

  describe "change_password" do
    test "succeeds with correct current password" do
      user = register_user!()

      assert {:ok, _} =
               Accounts.change_password(
                 user,
                 %{
                   current_password: "password123",
                   password: "newpassword456",
                   password_confirmation: "newpassword456"
                 },
                 authorize?: false
               )
    end

    test "rejects wrong current password" do
      user = register_user!()

      assert {:error, _} =
               Accounts.change_password(
                 user,
                 %{
                   current_password: "wrongpassword",
                   password: "newpassword456",
                   password_confirmation: "newpassword456"
                 },
                 authorize?: false
               )
    end
  end

  describe "email confirmation" do
    test "new user is unconfirmed" do
      user = register_user!()

      assert is_nil(user.confirmed_at)
    end

    test "registration sends confirmation email" do
      register_user!(email: "confirm@example.com")

      assert_email_sent(fn sent ->
        sent.subject == "Confirm your email address" &&
          Enum.any?(sent.to, fn {_, addr} -> addr == "confirm@example.com" end)
      end)
    end
  end

  describe "request_password_reset_token" do
    test "does not raise for existing email" do
      user = register_user!()
      Accounts.request_password_reset_token!(user.email, authorize?: false)
    end

    test "does not raise for non-existent email" do
      Accounts.request_password_reset_token!("nobody@example.com", authorize?: false)
    end
  end

  describe "authorization" do
    test "user can read own profile" do
      user = register_user!()

      assert {:ok, _} = Accounts.get_user_by_id(user.id, actor: user)
    end

    test "user cannot read another user" do
      user = register_user!()
      other = register_user!()

      assert {:error, %Ash.Error.Invalid{}} = Accounts.get_user_by_id(other.id, actor: user)
    end

    test "unauthenticated read returns error" do
      register_user!()

      assert {:error, _} = Accounts.get_user_by_email("test@example.com", actor: nil)
    end

    test "user can update own profile" do
      user = register_user!()

      assert {:ok, updated} =
               Accounts.update_profile(user, %{first_name: "Ola"}, actor: user)

      assert updated.first_name == "Ola"
    end

    test "user cannot update another user's profile" do
      user = register_user!()
      other = register_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.update_profile(other, %{first_name: "Nope"}, actor: user)
    end

    test "unauthenticated profile update is forbidden" do
      user = register_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.update_profile(user, %{first_name: "Hacker"}, actor: nil)
    end

    test "user can change own password" do
      user = register_user!()

      assert {:ok, _} =
               Accounts.change_password(
                 user,
                 %{
                   current_password: "password123",
                   password: "newpassword456",
                   password_confirmation: "newpassword456"
                 },
                 actor: user
               )
    end

    test "user cannot change another user's password" do
      user = register_user!()
      other = register_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.change_password(
                 other,
                 %{
                   current_password: "password123",
                   password: "newpassword456",
                   password_confirmation: "newpassword456"
                 },
                 actor: user
               )
    end
  end
end
