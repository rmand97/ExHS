defmodule ExhsWeb.Labels do
  @moduledoc """
  Shared user-facing labels and badge variants for payments, payable types, and
  event registrations. Labels are English msgids translated via `ExhsWeb.Gettext`.
  Membership role/status labels and date/money formatting live in
  `ExhsWeb.DisplayHelpers`, which is imported globally.
  """
  use Gettext, backend: ExhsWeb.Gettext

  @roles ~w(admin board member)

  @doc "Parse a role string into an existing atom, defaulting to :member."
  def to_role(role) when role in @roles, do: String.to_existing_atom(role)
  def to_role(_), do: :member

  @doc "Display name for a membership: full name, falling back to email."
  def member_name(%{user: user}) do
    given = blank_to_nil(user.first_name)
    surname = blank_to_nil(user.last_name)

    if is_nil(given) and is_nil(surname) do
      to_string(user.email)
    else
      {:ok, name} =
        Localize.PersonName.new(
          given_name: given,
          surname: surname,
          locale: Localize.get_locale()
        )

      Localize.PersonName.to_string!(name, format: :long, usage: :referring)
    end
  end

  defp blank_to_nil(value) do
    case value && String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  @doc "Format integer øre/cents in the current locale, e.g. 30000 -> \"300,00 kr.\" (da)."
  def format_amount(cents, currency \\ "DKK") when is_integer(cents) do
    ExhsWeb.DisplayHelpers.format_money(cents, currency)
  end

  def payment_status_label(:succeeded), do: gettext("Paid")
  def payment_status_label(:pending), do: gettext("Pending")
  def payment_status_label(:failed), do: gettext("Failed")
  def payment_status_label(:refunded), do: gettext("Refunded")
  def payment_status_label(other), do: to_string(other)

  def payment_status_variant(:succeeded), do: "success"
  def payment_status_variant(:pending), do: "warning"
  def payment_status_variant(:failed), do: "error"
  def payment_status_variant(:refunded), do: "default"
  def payment_status_variant(_), do: "default"

  def payable_type_label(:subscription), do: gettext("Membership fee")
  def payable_type_label(:registration), do: gettext("Event")
  def payable_type_label(:order), do: gettext("Order")
  def payable_type_label(other), do: to_string(other)

  def reg_status_label(:confirmed), do: gettext("Confirmed")
  def reg_status_label(:waitlisted), do: gettext("Waitlist")
  def reg_status_label(:cancelled), do: gettext("Cancelled")
  def reg_status_label(:pending_payment), do: gettext("Awaiting payment")
  def reg_status_label(other), do: to_string(other)

  def reg_status_variant(:confirmed), do: "success"
  def reg_status_variant(:waitlisted), do: "warning"
  def reg_status_variant(:cancelled), do: "error"
  def reg_status_variant(:pending_payment), do: "default"
  def reg_status_variant(_), do: "default"

  def order_status_label(:paid), do: gettext("Paid")
  def order_status_label(:pending_payment), do: gettext("Awaiting payment")
  def order_status_label(:building), do: gettext("Draft")
  def order_status_label(:cancelled), do: gettext("Cancelled")
  def order_status_label(:expired), do: gettext("Expired")
  def order_status_label(other), do: to_string(other)

  def order_status_variant(:paid), do: "success"
  def order_status_variant(:pending_payment), do: "warning"
  def order_status_variant(:cancelled), do: "error"
  def order_status_variant(:expired), do: "error"
  def order_status_variant(_), do: "default"

  @doc "Label for an audit-log action, falling back to a humanized atom."
  def action_label(:create), do: gettext("Created")
  def action_label(:update), do: gettext("Updated")
  def action_label(:destroy), do: gettext("Deleted")
  def action_label(:invite), do: gettext("Invited")
  def action_label(:set_role), do: gettext("Role changed")
  def action_label(:activate), do: gettext("Activated")
  def action_label(:deactivate), do: gettext("Deactivated")
  def action_label(:join), do: gettext("Joined")
  def action_label(:leave), do: gettext("Left")
  def action_label(:publish), do: gettext("Published")
  def action_label(:register), do: gettext("Registered")
  def action_label(:record), do: gettext("Recorded")
  def action_label(:set_stripe_account), do: gettext("Stripe connected")
  def action_label(:set_stripe_customer), do: gettext("Stripe customer set")

  def action_label(action) do
    action |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end
end
