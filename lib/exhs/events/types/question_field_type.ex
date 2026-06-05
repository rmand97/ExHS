defmodule Exhs.Events.Types.QuestionFieldType do
  @moduledoc false
  use Ash.Type.Enum, values: [:text, :select, :number]
end
