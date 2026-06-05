defmodule ExhsWeb.DisplayHelpers do
  @moduledoc false
  use ExhsWeb, :verified_routes

  def format_date(nil), do: "—"
  def format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%d. %b %Y")
  def format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d. %b %Y")
  def format_date(%Date{} = d), do: Calendar.strftime(d, "%d. %b %Y")

  def format_datetime(nil), do: "—"
  def format_datetime(dt), do: Calendar.strftime(dt, "%d. %b %Y, kl. %H:%M")

  def role_variant(:admin), do: "error"
  def role_variant(:board), do: "warning"
  def role_variant(_), do: "default"

  def role_label(:admin), do: "Admin"
  def role_label(:board), do: "Bestyrelse"
  def role_label(:member), do: "Medlem"

  def status_variant(:active), do: "success"
  def status_variant(:inactive), do: "default"

  def status_label(:active), do: "Aktiv"
  def status_label(:inactive), do: "Inaktiv"

  def format_kontingent(%{kontingent_amount_cents: nil}), do: "Gratis"
  def format_kontingent(%{kontingent_amount_cents: 0}), do: "Gratis"

  def format_kontingent(%{kontingent_amount_cents: cents, kontingent_currency: currency}),
    do: "#{div(cents, 100)} #{currency || "DKK"}"

  def format_price(0, _currency), do: "Gratis"
  def format_price(cents, currency), do: "#{div(cents, 100)} #{currency}"

  def forening_url(forening), do: ~p"/go/forening/#{forening.subdomain}"
end
