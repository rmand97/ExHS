defmodule ExhsWeb.AdminLive.Economy.Index do
  @moduledoc false
  use ExhsWeb, :live_view

  import ExhsWeb.Labels

  alias Exhs.Billing
  alias Exhs.Billing.PaymentFilter
  alias Exhs.Billing.Revenue
  alias Exhs.Billing.Types.PayableType
  alias Exhs.Billing.Types.PaymentStatus

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Økonomi")
     |> assign(:filters, %{})
     |> load_payments()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      status: params["status"],
      type: params["type"],
      month: params["month"],
      sort: params["sort"],
      q: params["q"]
    }

    {:noreply, socket |> assign(:filters, filters) |> stream_filtered()}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    query =
      filters
      |> Map.take(~w(status type month sort q))
      |> Map.reject(fn {_, v} -> v in [nil, ""] end)

    {:noreply, push_patch(socket, to: ~p"/admin/economy?#{query}")}
  end

  def handle_event("refund", %{"id" => id}, socket) do
    payment = Enum.find(socket.assigns.all_payments, &(&1.id == id))

    socket =
      with %{} <- payment,
           {:ok, _} <- Billing.mark_payment_refunded(payment, scope: socket.assigns.current_scope) do
        put_flash(socket, :info, "Betaling markeret som refunderet.")
      else
        _ -> put_flash(socket, :error, "Kunne ikke opdatere betalingen.")
      end

    {:noreply, socket |> load_payments() |> stream_filtered()}
  end

  defp load_payments(socket) do
    {:ok, payments} =
      Billing.list_payments(scope: socket.assigns.current_scope, authorize?: false)

    socket
    |> assign(:all_payments, payments)
    |> assign(:summary, Revenue.summary(payments))
  end

  defp stream_filtered(socket) do
    rows = PaymentFilter.apply(socket.assigns.all_payments, socket.assigns.filters)

    socket
    |> assign(:row_count, length(rows))
    |> stream(:payments, rows, reset: true)
  end

  defp month_options(by_month) do
    Enum.map(by_month, fn {{year, month}, _cents} ->
      key = "#{year}-#{String.pad_leading(to_string(month), 2, "0")}"
      {key, key}
    end)
  end

  defp month_label({year, month}) do
    "#{String.pad_leading(to_string(month), 2, "0")}/#{year}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      current_forening={@current_forening}
      current_role={@current_role}
      current_path={@current_path}
    >
      <.header>
        Økonomi
        <:subtitle>Indtægter, betalinger og bogføring</:subtitle>
        <:actions>
          <.link
            href={
              ~p"/admin/export/payments.csv?#{Map.reject(@filters, fn {_, v} -> v in [nil, ""] end)}"
            }
            class="btn btn-outline btn-sm"
          >
            <.icon name="hero-arrow-down-tray" class="size-4" /> Eksportér CSV
          </.link>
        </:actions>
      </.header>

      <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.card class="p-5">
          <p class="text-base-content/50 text-sm">Realiseret omsætning</p>
          <p class="text-base-content mt-1 text-2xl font-bold">
            {format_amount(@summary.total_cents)}
          </p>
        </.card>
        <.card class="p-5">
          <p class="text-base-content/50 text-sm">Udestående</p>
          <p class="text-base-content mt-1 text-2xl font-bold">
            {format_amount(@summary.outstanding_cents)}
          </p>
        </.card>
        <.card :for={{type, cents} <- @summary.by_type} class="p-5">
          <p class="text-base-content/50 text-sm">{payable_type_label(type)}</p>
          <p class="text-base-content mt-1 text-2xl font-bold">{format_amount(cents)}</p>
        </.card>
      </div>

      <.card :if={@summary.by_month != []} class="mt-4 p-5">
        <h3 class="text-base-content mb-3 font-semibold">Omsætning pr. måned</h3>
        <ul class="divide-base-content/10 divide-y">
          <li :for={{month, cents} <- @summary.by_month} class="flex justify-between py-2 text-sm">
            <span class="text-base-content/70">{month_label(month)}</span>
            <span class="text-base-content font-medium">{format_amount(cents)}</span>
          </li>
        </ul>
      </.card>

      <.form
        for={%{}}
        phx-change="filter"
        class="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3"
      >
        <select name="filters[status]" class="select select-bordered select-sm w-full">
          <option value="">Alle statusser</option>
          <option
            :for={s <- PaymentStatus.values()}
            value={s}
            selected={@filters[:status] == to_string(s)}
          >
            {payment_status_label(s)}
          </option>
        </select>
        <select name="filters[type]" class="select select-bordered select-sm w-full">
          <option value="">Alle typer</option>
          <option
            :for={t <- PayableType.values()}
            value={t}
            selected={@filters[:type] == to_string(t)}
          >
            {payable_type_label(t)}
          </option>
        </select>
        <select name="filters[month]" class="select select-bordered select-sm w-full">
          <option value="">Alle måneder</option>
          <option
            :for={{key, label} <- month_options(@summary.by_month)}
            value={key}
            selected={@filters[:month] == key}
          >
            {label}
          </option>
        </select>
        <select name="filters[sort]" class="select select-bordered select-sm w-full">
          <option value="">Nyeste først</option>
          <option value="oldest" selected={@filters[:sort] == "oldest"}>Ældste først</option>
          <option value="amount_desc" selected={@filters[:sort] == "amount_desc"}>
            Beløb (høj→lav)
          </option>
          <option value="amount_asc" selected={@filters[:sort] == "amount_asc"}>
            Beløb (lav→høj)
          </option>
        </select>
        <input
          type="search"
          name="filters[q]"
          value={@filters[:q]}
          placeholder="Søg beskrivelse"
          class="input input-bordered input-sm w-full sm:col-span-2 lg:col-span-1"
        />
      </.form>

      <div :if={@row_count == 0} class="mt-8">
        <.empty_state icon="hero-banknotes" title="Ingen betalinger">
          Der er ingen betalinger, der matcher dine filtre.
        </.empty_state>
      </div>

      <div :if={@row_count > 0} id="payments" phx-update="stream" class="mt-4 space-y-2">
        <div
          :for={{dom_id, p} <- @streams.payments}
          id={dom_id}
          class="border-base-content/5 flex flex-wrap items-center justify-between gap-x-4 gap-y-2 rounded-xl border p-3"
        >
          <div class="min-w-0 flex-1">
            <p class="text-base-content truncate text-sm font-medium">
              {p.description || payable_type_label(p.payable_type)}
            </p>
            <p class="text-base-content/50 mt-0.5 flex items-center gap-2 text-xs">
              {format_date(p.paid_at)}
              <.badge variant="default">{payable_type_label(p.payable_type)}</.badge>
            </p>
          </div>
          <div class="flex items-center gap-3">
            <span class="text-base-content text-sm font-semibold whitespace-nowrap">
              {format_amount(p.amount_cents, p.currency)}
            </span>
            <.badge variant={payment_status_variant(p.status)}>
              {payment_status_label(p.status)}
            </.badge>
            <.button
              :if={@can_write? and p.status == :succeeded}
              variant="ghost"
              class="btn btn-ghost btn-xs"
              phx-click="refund"
              phx-value-id={p.id}
              data-confirm="Markér betalingen som refunderet? (udløser ikke en Stripe-refundering)"
            >
              Refundér
            </.button>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
