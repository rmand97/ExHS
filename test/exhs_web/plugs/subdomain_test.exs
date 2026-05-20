defmodule ExhsWeb.Plugs.SubdomainTest do
  use ExhsWeb.ConnCase, async: true

  alias Exhs.Organizations

  defp create_forening!(subdomain) do
    Organizations.create_forening!(
      %{
        name: "Test #{subdomain}",
        slug: "slug-#{System.unique_integer([:positive])}",
        subdomain: subdomain
      },
      authorize?: false
    )
  end

  describe "subdomain plug" do
    test "assigns current_forening for valid subdomain", %{conn: conn} do
      forening = create_forening!("klubben")

      conn =
        conn
        |> Map.put(:host, "klubben.lvh.me")
        |> get("/")

      assert conn.assigns[:current_forening].id == forening.id
      assert conn.assigns[:current_tenant] == forening.id
    end

    test "returns 404 for unknown subdomain", %{conn: conn} do
      conn =
        conn
        |> Map.put(:host, "nonexistent.lvh.me")
        |> get("/")

      assert conn.status == 404
      assert conn.halted
    end

    test "skips for bare localhost", %{conn: conn} do
      conn =
        conn
        |> Map.put(:host, "localhost")
        |> get("/")

      refute conn.assigns[:current_forening]
      refute conn.halted
    end

    test "skips for reserved subdomains", %{conn: conn} do
      conn =
        conn
        |> Map.put(:host, "www.lvh.me")
        |> get("/")

      refute conn.assigns[:current_forening]
      refute conn.halted
    end
  end
end
