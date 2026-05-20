defmodule ExhsWeb.LiveForeningAuth do
  @moduledoc false
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:require_forening, _params, _session, socket) do
    case socket.assigns do
      %{current_forening: %Exhs.Organizations.Forening{}} ->
        {:cont, assign_scope(socket)}

      _ ->
        {:halt, redirect(socket, to: "/")}
    end
  end

  def on_mount(:optional_forening, _params, _session, socket) do
    if socket.assigns[:current_forening] do
      {:cont, assign_scope(socket)}
    else
      {:cont, assign(socket, :current_scope, nil)}
    end
  end

  defp assign_scope(socket) do
    scope = %Exhs.Scope{
      actor: socket.assigns[:current_user],
      tenant: socket.assigns.current_forening.id
    }

    assign(socket, :current_scope, scope)
  end
end
