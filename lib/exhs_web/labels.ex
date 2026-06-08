defmodule ExhsWeb.Labels do
  @moduledoc """
  Shared Danish labels and badge variants for payments, payable types, and
  event registrations. Membership role/status labels and date formatting live
  in `ExhsWeb.DisplayHelpers`, which is imported globally.
  """

  @roles ~w(admin board member)

  @doc "Parse a role string into an existing atom, defaulting to :member."
  def to_role(role) when role in @roles, do: String.to_existing_atom(role)
  def to_role(_), do: :member

  @doc "Display name for a membership: full name, falling back to email."
  def member_name(%{user: user}) do
    name = String.trim("#{user.first_name} #{user.last_name}")
    if name == "", do: to_string(user.email), else: name
  end

  @doc "Format integer øre/cents as a Danish currency string, e.g. 30000 -> \"300 DKK\"."
  def format_amount(cents, currency \\ "DKK") when is_integer(cents) do
    "#{div(cents, 100)} #{currency}"
  end

  def payment_status_label(:succeeded), do: "Betalt"
  def payment_status_label(:pending), do: "Afventer"
  def payment_status_label(:failed), do: "Fejlet"
  def payment_status_label(:refunded), do: "Refunderet"
  def payment_status_label(other), do: to_string(other)

  def payment_status_variant(:succeeded), do: "success"
  def payment_status_variant(:pending), do: "warning"
  def payment_status_variant(:failed), do: "error"
  def payment_status_variant(:refunded), do: "default"
  def payment_status_variant(_), do: "default"

  def payable_type_label(:subscription), do: "Kontingent"
  def payable_type_label(:registration), do: "Event"
  def payable_type_label(:order), do: "Ordre"
  def payable_type_label(other), do: to_string(other)

  def reg_status_label(:confirmed), do: "Bekræftet"
  def reg_status_label(:waitlisted), do: "Venteliste"
  def reg_status_label(:cancelled), do: "Annulleret"
  def reg_status_label(:pending_payment), do: "Afventer betaling"
  def reg_status_label(other), do: to_string(other)

  def reg_status_variant(:confirmed), do: "success"
  def reg_status_variant(:waitlisted), do: "warning"
  def reg_status_variant(:cancelled), do: "error"
  def reg_status_variant(:pending_payment), do: "default"
  def reg_status_variant(_), do: "default"

  def order_status_label(:paid), do: "Betalt"
  def order_status_label(:pending_payment), do: "Afventer betaling"
  def order_status_label(:building), do: "Kladde"
  def order_status_label(:cancelled), do: "Annulleret"
  def order_status_label(:expired), do: "Udløbet"
  def order_status_label(other), do: to_string(other)

  def order_status_variant(:paid), do: "success"
  def order_status_variant(:pending_payment), do: "warning"
  def order_status_variant(:cancelled), do: "error"
  def order_status_variant(:expired), do: "error"
  def order_status_variant(_), do: "default"

  @action_labels %{
    create: "Oprettet",
    update: "Opdateret",
    destroy: "Slettet",
    invite: "Inviteret",
    set_role: "Rolle ændret",
    activate: "Aktiveret",
    deactivate: "Deaktiveret",
    join: "Tilmeldt",
    leave: "Forladt",
    publish: "Publiceret",
    register: "Tilmeldt",
    record: "Registreret",
    set_stripe_account: "Stripe tilsluttet",
    set_stripe_customer: "Stripe-kunde sat"
  }

  @doc "Danish label for an audit-log action, falling back to a humanized atom."
  def action_label(action) do
    Map.get(
      @action_labels,
      action,
      action |> to_string() |> String.replace("_", " ") |> String.capitalize()
    )
  end
end
