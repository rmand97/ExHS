defmodule ExhsWeb.Components.Avatar do
  @moduledoc false
  use Phoenix.Component

  attr :src, :string, default: nil
  attr :initials, :string, default: "?"
  attr :size, :string, default: "md", values: ~w(xs sm md lg)
  attr :class, :any, default: nil

  def avatar(assigns) do
    sizes = %{
      "xs" => "w-6 h-6 text-[10px]",
      "sm" => "w-8 h-8 text-xs",
      "md" => "w-10 h-10 text-sm",
      "lg" => "w-14 h-14 text-base"
    }

    assigns = assign(assigns, :size_class, Map.fetch!(sizes, assigns.size))

    ~H"""
    <div class={[
      "flex shrink-0 items-center justify-center overflow-hidden rounded-xl font-semibold",
      @size_class,
      @class
    ]}>
      <img :if={@src} src={@src} class="size-full object-cover" />
      <div
        :if={!@src}
        class="from-primary text-primary-content to-secondary flex size-full items-center justify-center bg-linear-to-br"
      >
        {@initials}
      </div>
    </div>
    """
  end
end
