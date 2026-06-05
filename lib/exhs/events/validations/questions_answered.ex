defmodule Exhs.Events.Validations.QuestionsAnswered do
  @moduledoc """
  Validates a ticket item's `responses` against its ticket type's custom
  questions: required questions must be answered, `:select` answers must be one
  of the configured options, and `:number` answers must be numeric.
  """
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :item_type) do
      :ticket -> validate_ticket(changeset)
      _ -> :ok
    end
  end

  defp validate_ticket(changeset) do
    ticket_type_id = Ash.Changeset.get_attribute(changeset, :ticket_type_id)
    do_validate_ticket(changeset, ticket_type_id)
  end

  defp do_validate_ticket(_changeset, nil), do: :ok

  defp do_validate_ticket(changeset, ticket_type_id) do
    responses = Ash.Changeset.get_attribute(changeset, :responses) || %{}
    tenant = changeset.tenant

    ticket_type_id
    |> questions(tenant)
    |> Enum.reduce_while(:ok, fn question, :ok ->
      case validate_answer(question, Map.get(responses, question.id)) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp questions(ticket_type_id, tenant) do
    Exhs.Events.TicketTypeQuestion
    |> Ash.Query.filter(ticket_type_id == ^ticket_type_id)
    |> Ash.read!(tenant: tenant, authorize?: false)
  end

  defp validate_answer(%{required: true} = q, answer) when answer in [nil, ""],
    do: {:error, field: :responses, message: "#{q.label} is required"}

  defp validate_answer(_q, answer) when answer in [nil, ""], do: :ok

  defp validate_answer(%{field_type: :select, options: options} = q, answer) do
    if answer in options do
      :ok
    else
      {:error, field: :responses, message: "#{q.label}: invalid choice"}
    end
  end

  defp validate_answer(%{field_type: :number} = q, answer) do
    case Float.parse(to_string(answer)) do
      {_num, ""} -> :ok
      _ -> {:error, field: :responses, message: "#{q.label} must be a number"}
    end
  end

  defp validate_answer(_q, _answer), do: :ok
end
