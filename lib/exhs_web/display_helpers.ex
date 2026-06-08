defmodule ExhsWeb.DisplayHelpers do
  @moduledoc false
  use ExhsWeb, :verified_routes
  use Gettext, backend: ExhsWeb.Gettext

  def format_date(nil), do: "—"
  def format_date(date), do: Localize.Date.to_string!(date, format: :medium)

  def format_datetime(nil), do: "—"

  def format_datetime(dt) do
    date = Localize.Date.to_string!(dt, format: :medium)
    time = Localize.Time.to_string!(dt, format: :short)
    "#{date}, #{time}"
  end

  def role_variant(:admin), do: "error"
  def role_variant(:board), do: "warning"
  def role_variant(_), do: "default"

  def role_label(:admin), do: gettext("Admin")
  def role_label(:board), do: gettext("Board")
  def role_label(:member), do: gettext("Member")

  def status_variant(:active), do: "success"
  def status_variant(:inactive), do: "default"

  def status_label(:active), do: gettext("Active")
  def status_label(:inactive), do: gettext("Inactive")

  def format_kontingent(%{kontingent_amount_cents: nil}), do: gettext("Free")
  def format_kontingent(%{kontingent_amount_cents: 0}), do: gettext("Free")

  def format_kontingent(%{kontingent_amount_cents: cents, kontingent_currency: currency}),
    do: format_money(cents, currency)

  def format_price(0, _currency), do: gettext("Free")
  def format_price(cents, currency), do: format_money(cents, currency)

  @doc "Format integer øre/cents in the current locale, e.g. 30000 -> \"300,00 kr.\" (da)."
  def format_money(cents, currency) when is_integer(cents) do
    Decimal.new(cents)
    |> Decimal.div(100)
    |> Localize.Number.to_string!(currency: currency_code(currency || "DKK"))
  end

  defp currency_code(code) when is_atom(code), do: code

  defp currency_code(code) when is_binary(code) do
    String.to_existing_atom(code)
  rescue
    ArgumentError -> :DKK
  end

  def forening_url(forening), do: ~p"/go/forening/#{forening.subdomain}"
end
