defmodule Exhs.Storage.CleanupWorkerTest do
  use Exhs.DataCase, async: true
  use Oban.Testing, repo: Exhs.Repo

  alias Exhs.Storage
  alias Exhs.Storage.CleanupWorker

  describe "perform/1" do
    test "deletes the S3 object for the given key" do
      key = "uploads/users/123/avatar/#{Ash.UUID.generate()}.png"
      :ok = Storage.put(key, "data", "image/png")
      assert Storage.Stub.stored?(key)

      assert :ok = perform_job(CleanupWorker, %{key: key})
      refute Storage.Stub.stored?(key)
    end

    test "returns error when storage fails" do
      Storage.Stub.set_response(:delete, {:error, :unavailable})
      assert {:error, :unavailable} = perform_job(CleanupWorker, %{key: "any-key"})
    end
  end

  describe "enqueue/1" do
    test "inserts and executes an Oban job (inline mode)" do
      key = "uploads/users/456/avatar/#{Ash.UUID.generate()}.png"
      :ok = Storage.put(key, "data", "image/png")
      assert Storage.Stub.stored?(key)

      assert {:ok, %Oban.Job{}} = CleanupWorker.enqueue(key)
      refute Storage.Stub.stored?(key)
    end
  end
end
