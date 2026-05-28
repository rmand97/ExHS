defmodule ExhsWeb.PublicLive.Join do
  @moduledoc false
  use ExhsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_forening] do
      forening = socket.assigns.current_forening

      {:ok,
       assign(socket,
         page_title: "Bliv medlem af #{forening.name}",
         page_description:
           "Bliv medlem af #{forening.name} og få adgang til events, fællesskab og meget mere.",
         kontingent_amount: format_kontingent(forening)
       )}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.public
      flash={@flash}
      current_forening={@current_forening}
      current_user={@current_user}
    >
      <div class="px-4 py-16 sm:px-6">
        <div class="mx-auto max-w-2xl text-center">
          <h1 class="text-base-content text-3xl font-bold sm:text-4xl">
            Bliv medlem af {@current_forening.name}
          </h1>
          <p class="text-base-content/60 mt-4 text-lg">
            Opret konto og få adgang til events, fællesskab og meget mere.
          </p>
        </div>

        <div class="mx-auto mt-12 max-w-lg">
          <.card class="p-6 sm:p-8">
            <div class="space-y-6">
              <.benefit icon="hero-calendar-days" text="Adgang til alle medlemsevents" />
              <.benefit icon="hero-user-group" text="Del af fællesskabet" />
              <.benefit icon="hero-bell" text="Nyheder og opdateringer" />
              <.benefit
                :if={@kontingent_amount}
                icon="hero-banknotes"
                text={"Kontingent: #{@kontingent_amount}"}
              />
            </div>

            <div class="border-base-content/5 mt-8 border-t pt-6">
              <a :if={!@current_user} href="/register" class="btn btn-block btn-lg btn-primary">
                Opret konto
              </a>
              <a :if={@current_user} href="/" class="btn btn-block btn-lg btn-primary">
                Bliv medlem
              </a>
              <p :if={!@current_user} class="text-base-content/50 mt-3 text-center text-sm">
                Har du allerede en konto?
                <a href="/sign-in" class="text-primary hover:underline">Log ind</a>
              </p>
            </div>
          </.card>
        </div>
      </div>
    </Layouts.public>
    """
  end

  defp benefit(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="bg-primary/10 text-primary flex size-10 shrink-0 items-center justify-center rounded-lg">
        <.icon name={@icon} class="size-5" />
      </div>
      <p class="text-base-content">{@text}</p>
    </div>
    """
  end

  defp format_kontingent(%{kontingent_amount_cents: nil}), do: nil
  defp format_kontingent(%{kontingent_amount_cents: 0}), do: "Gratis"

  defp format_kontingent(%{kontingent_amount_cents: cents, kontingent_currency: currency}) do
    "#{div(cents, 100)} #{currency || "DKK"}/år"
  end
end
