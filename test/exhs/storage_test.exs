defmodule Exhs.StorageTest do
  use Exhs.StorageIntegrationCase, async: false

  alias Exhs.Storage

  @moduletag :integration

  defp unique_key(prefix \\ "test") do
    uuid = Ash.UUID.generate()
    "test-uploads/#{prefix}/#{uuid}.txt"
  end

  describe "put/3 + head/1 roundtrip" do
    test "uploads an object and verifies it exists" do
      key = unique_key()
      assert :ok = Storage.put(key, "hello world", "text/plain")
      assert {:ok, headers} = Storage.head(key)
      assert headers["content-type"] == "text/plain"
    end
  end

  describe "delete/1" do
    test "removes an uploaded object" do
      key = unique_key()
      :ok = Storage.put(key, "delete me", "text/plain")
      assert {:ok, _} = Storage.head(key)

      assert :ok = Storage.delete(key)
      assert {:error, _} = Storage.head(key)
    end

    test "succeeds on nonexistent key (S3 delete is idempotent)" do
      key = unique_key("nonexistent")
      assert :ok = Storage.delete(key)
    end
  end

  describe "presigned_put_url/3" do
    test "generates a usable presigned PUT URL" do
      key = unique_key("presigned")
      {:ok, url} = Storage.presigned_put_url(key, "text/plain")

      assert url =~ key
      assert url =~ "X-Amz-Signature"

      Req.put!(url, body: "presigned upload", headers: [{"content-type", "text/plain"}])

      assert {:ok, headers} = Storage.head(key)
      assert headers["content-type"] == "text/plain"
    end
  end

  describe "public_url/1" do
    test "returns a URL containing the bucket and key" do
      key = "uploads/users/123/avatar/abc.png"
      url = Storage.public_url(key)
      assert url =~ Storage.bucket()
      assert url =~ key
    end
  end

  describe "generate_key/4" do
    test "produces a unique key with correct structure" do
      key1 = Storage.generate_key("users", "123", "avatar", "photo.jpg")
      key2 = Storage.generate_key("users", "123", "avatar", "photo.jpg")

      assert key1 =~ "uploads/users/123/avatar/"
      assert key1 =~ ".jpg"
      assert key1 != key2
    end
  end
end
