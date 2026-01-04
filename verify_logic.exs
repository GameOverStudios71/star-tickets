defmodule MockProjection do
  defstruct [:name, :expected_action, :resource_id, :status, :deadline]
end

defmodule MockLog do
  defstruct [:action, :resource_id, :details]
end

# Replicate the logic from Overseer exactly
defmodule LogicCheck do
  def matches?(log, projection) do
    action_match = log.action == projection.expected_action

    resource_match =
      if projection.resource_id do
        projection.resource_id == log.resource_id
      else
        true
      end

    basic_match = action_match and resource_match

    if basic_match and log.action == "TICKET_UPDATED" do
      expected_status_fragment =
        cond do
          String.contains?(projection.name, "Chamada Recepção") -> "CALLED_RECEPTION"
          String.contains?(projection.name, "Chamada Médico") -> "CALLED_PROFESSIONAL"
          String.contains?(projection.name, "Finalização") -> "FINISHED"
          true -> nil
        end

      if expected_status_fragment do
        # Emulate Inspect as Overseer does
        details_str = inspect(log.details, pretty: true)
        IO.puts("Checking content: #{details_str}")
        IO.puts("Looking for: #{expected_status_fragment}")
        String.contains?(details_str, expected_status_fragment)
      else
        true
      end
    else
      basic_match
    end
  end
end

defmodule Run do
  def run do
    # Setup Data
    log = %MockLog{
      action: "TICKET_UPDATED",
      resource_id: "123",
      details: %{
        diff: %{
          status: %{from: "WAITING_RECEPTION", to: "CALLED_RECEPTION"},
          updated_at: %{from: ~U[2024-01-01 10:00:00Z], to: ~U[2024-01-01 10:01:00Z]}
        },
        original_state: %{status: "WAITING_RECEPTION"}
      }
    }

    projection = %MockProjection{
      name: "2. Chamada Recepção",
      expected_action: "TICKET_UPDATED",
      # String match
      resource_id: "123",
      status: :pending
    }

    IO.puts("--- Test 1: Reception Call Match ---")
    match = LogicCheck.matches?(log, projection)
    IO.puts("Match Result: #{match}")

    if match do
      IO.puts("✅ Logic is correct.")
    else
      IO.puts("❌ Logic FAILED.")
      System.halt(1)
    end
  end
end

Run.run()
