defmodule ExhsWeb.AdminLive.MembersPubSub do
  @moduledoc """
  Thin wrapper around `Phoenix.PubSub` for live membership updates in the admin
  area. When one admin mutates members (invite, activate, role, groups), every
  connected admin viewing the same forening reloads. Topic is per-forening so
  tenants never receive each other's broadcasts.
  """

  @pubsub Exhs.PubSub

  def subscribe(forening_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(forening_id))
  end

  def broadcast(forening_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(forening_id), :members_changed)
  end

  defp topic(forening_id), do: "admin:members:#{forening_id}"
end
