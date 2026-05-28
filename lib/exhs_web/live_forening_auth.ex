defmodule ExhsWeb.LiveForeningAuth do
  @moduledoc false
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:require_forening, _params, session, socket) do
    socket = maybe_load_forening(socket, session)

    case socket.assigns do
      %{current_forening: %Exhs.Organizations.Forening{}} ->
        {:cont, assign_scope(socket)}

      _ ->
        {:halt, redirect(socket, to: "/")}
    end
  end

  def on_mount(:optional_forening, _params, session, socket) do
    socket = maybe_load_forening(socket, session)

    if socket.assigns[:current_forening] do
      {:cont, assign_scope(socket)}
    else
      {:cont, assign(socket, current_scope: nil, current_forening: nil)}
    end
  end

  defp maybe_load_forening(
         %{assigns: %{current_forening: %Exhs.Organizations.Forening{}}} = socket,
         _session
       ) do
    socket
  end

  defp maybe_load_forening(socket, %{"current_forening_id" => id}) when is_binary(id) do
    case Exhs.Organizations.get_forening_by_id(id, authorize?: false) do
      {:ok, forening} ->
        assign(socket, current_forening: forening, current_tenant: forening.id)

      _ ->
        socket
    end
  end

  defp maybe_load_forening(socket, _session), do: socket

  defp assign_scope(socket) do
    scope = %Exhs.Scope{
      actor: socket.assigns[:current_user],
      tenant: socket.assigns.current_forening.id
    }

    assign(socket, :current_scope, scope)
  end
end
