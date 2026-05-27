defmodule Exhs.Storage.StubTest do
  use Exhs.DataCase, async: true

  alias Exhs.Storage
  alias Exhs.Storage.Stub

  describe "stub put/head/delete roundtrip" do
    test "stores and retrieves via stub" do
      key = "test/#{Ash.UUID.generate()}.txt"
      assert :ok = Storage.put(key, "data", "text/plain")
      assert {:ok, meta} = Storage.head(key)
      assert meta["content-type"] == "text/plain"

      assert :ok = Storage.delete(key)
      assert {:error, :not_found} = Storage.head(key)
    end
  end

  describe "stub set_response override" do
    test "returns custom error for put" do
      Stub.set_response(:put, {:error, :boom})
      assert {:error, :boom} = Storage.put("key", "data", "text/plain")
    end
  end

  describe "generate_key/4" do
    test "produces unique key with correct structure" do
      key1 = Storage.generate_key("users", "123", "avatar", "photo.jpg")
      key2 = Storage.generate_key("users", "123", "avatar", "photo.jpg")

      assert key1 =~ "uploads/users/123/avatar/"
      assert String.ends_with?(key1, ".jpg")
      assert key1 != key2
    end

    test "preserves file extension" do
      key = Storage.generate_key("events", "456", "cover", "banner.png")
      assert String.ends_with?(key, ".png")
    end
  end

  describe "public_url/1" do
    test "includes bucket and key" do
      key = "uploads/users/123/avatar/abc.png"
      url = Storage.public_url(key)
      assert url =~ Storage.bucket()
      assert url =~ key
    end
  end
end
