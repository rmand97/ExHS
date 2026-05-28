defmodule ExhsWeb.Components.Skeleton do
  @moduledoc false
  use Phoenix.Component

  attr :class, :any, default: "h-4 w-full"

  def skeleton(assigns) do
    ~H"""
    <div class={["bg-base-content/10 animate-pulse rounded-lg", @class]} />
    """
  end
end
