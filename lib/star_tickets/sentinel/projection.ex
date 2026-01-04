defmodule StarTickets.Sentinel.Projection do
  @moduledoc """
  Represents a future expectation of the system.
  Checking if the system behaves as predicted.
  """
  defstruct [
    :id,
    :name,
    :description,
    # The log that started this projection
    :trigger_event,
    # The action string we are waiting for
    :expected_action,
    # Optional filter
    :resource_type,
    # Optional filter
    :resource_id,
    :created_at,
    :deadline,
    # :pending, :verified, :failed
    :status,
    # 0.0 to 1.0 (AI confidence score - simulated)
    :confidence,
    :customer_name
  ]

  def new(attrs) do
    struct(
      __MODULE__,
      Keyword.merge(
        [
          id: Ecto.UUID.generate(),
          created_at: DateTime.utc_now(),
          status: :pending,
          confidence: 0.95
        ],
        attrs
      )
    )
  end
end
