defmodule ExhsWeb.Labels do
  @moduledoc """
  Shared Danish labels, badge variants, and formatting for membership roles,
  statuses, and dates. Used across member and admin LiveViews so the mapping
  lives in exactly one place.
  """

  def role_label(:admin), do: "Admin"
  def role_label(:board), do: "Bestyrelse"
  def role_label(:member), do: "Medlem"
  def role_label(_), do: "—"

  def role_variant(:admin), do: "error"
  def role_variant(:board), do: "warning"
  def role_variant(_), do: "default"

  def status_label(:active), do: "Aktiv"
  def status_label(:inactive), do: "Inaktiv"
  def status_label(_), do: "—"

  def status_variant(:active), do: "success"
  def status_variant(:inactive), do: "default"
  def status_variant(_), do: "default"

  @roles ~w(admin board member)

  @doc "Parse a role string into an existing atom, defaulting to :member."
  def to_role(role) when role in @roles, do: String.to_existing_atom(role)
  def to_role(_), do: :member

  @doc "Display name for a membership: full name, falling back to email."
  def member_name(%{user: user}) do
    name = String.trim("#{user.first_name} #{user.last_name}")
    if name == "", do: to_string(user.email), else: name
  end

  def format_date(nil), do: "—"
  def format_date(dt), do: Calendar.strftime(dt, "%d. %b %Y")

  def format_datetime(nil), do: "—"
  def format_datetime(dt), do: Calendar.strftime(dt, "%d. %b %Y %H:%M")

  @doc "Format integer øre/cents as a Danish currency string, e.g. 30000 -> \"300 DKK\"."
  def format_amount(cents, currency \\ "DKK") when is_integer(cents) do
    "#{div(cents, 100)} #{currency}"
  end
end
