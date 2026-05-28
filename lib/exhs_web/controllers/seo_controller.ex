defmodule ExhsWeb.SeoController do
  @moduledoc false
  use ExhsWeb, :controller

  def robots(conn, _params) do
    content =
      """
      User-agent: *
      Allow: /
      Disallow: /auth/
      Disallow: /dev/
      Disallow: /admin/

      Sitemap: #{url(~p"/sitemap.xml")}
      """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, content)
  end

  def sitemap(conn, _params) do
    forening = conn.assigns[:current_forening]

    urls =
      if forening do
        base = "#{conn.scheme}://#{conn.host}"
        event_urls = build_event_urls(forening, base)

        [
          url_entry(base <> "/", "daily", "1.0"),
          url_entry(base <> "/events", "daily", "0.8"),
          url_entry(base <> "/join", "weekly", "0.7")
          | event_urls
        ]
      else
        base = "#{conn.scheme}://#{conn.host}"

        [
          url_entry(base <> "/", "daily", "1.0")
        ]
      end

    xml = build_sitemap_xml(urls)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  defp build_event_urls(forening, base) do
    case Exhs.Events.list_public_events(tenant: forening.id) do
      {:ok, events} ->
        Enum.map(events, fn event ->
          url_entry(base <> "/events/#{event.id}", "weekly", "0.6")
        end)

      _ ->
        []
    end
  end

  defp url_entry(loc, changefreq, priority) do
    %{loc: loc, changefreq: changefreq, priority: priority}
  end

  defp build_sitemap_xml(urls) do
    entries =
      Enum.map_join(urls, "\n", fn %{loc: loc, changefreq: freq, priority: pri} ->
        """
          <url>
            <loc>#{escape_xml(loc)}</loc>
            <changefreq>#{freq}</changefreq>
            <priority>#{pri}</priority>
          </url>\
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{entries}
    </urlset>
    """
  end

  defp escape_xml(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
