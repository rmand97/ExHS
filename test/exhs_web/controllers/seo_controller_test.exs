defmodule ExhsWeb.SeoControllerTest do
  use ExhsWeb.ConnCase, async: true

  import Exhs.Test.Builders

  setup do
    forening =
      create_forening!(%{
        name: "SEO Forening",
        subdomain: "seotest"
      })

    event = create_published_event!(forening, %{title: "Testmatch"})

    %{forening: forening, event: event}
  end

  describe "robots.txt" do
    test "returns robots.txt with disallowed paths", %{conn: conn} do
      conn = get(conn, "/robots.txt")

      assert response(conn, 200)
      body = response(conn, 200)
      assert body =~ "User-agent: *"
      assert body =~ "Disallow: /auth/"
      assert body =~ "Disallow: /admin/"
      assert body =~ "Sitemap:"
    end
  end

  describe "sitemap.xml" do
    test "returns basic sitemap without subdomain", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")

      assert response(conn, 200)
      body = response(conn, 200)
      assert body =~ ~s(<?xml version="1.0")
      assert body =~ "<urlset"
      assert body =~ "<loc>"
    end

    test "includes events for forening subdomain", %{conn: conn, forening: forening} do
      conn =
        conn
        |> Map.put(:host, "#{forening.subdomain}.lvh.me")
        |> get("/sitemap.xml")

      body = response(conn, 200)
      assert body =~ "/events"
      assert body =~ "/join"
    end
  end
end
