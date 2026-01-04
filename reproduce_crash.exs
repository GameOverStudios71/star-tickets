Logger.configure(level: :error)
alias StarTickets.Tickets
alias StarTickets.Repo
alias StarTickets.Accounts
import Ecto.Query

# Get a user (receptionist) - assuming ID 2 is reception or similar, or just pick first user
user = Repo.one(from u in Accounts.User, limit: 1)
IO.puts("Using user: #{user.name} (#{user.id})")

# Create a ticket
IO.puts("Creating test ticket...")

{:ok, ticket} =
  Tickets.create_ticket(
    %{
      display_code: "TEST-#{System.unique_integer([:positive])}",
      establishment_id: 1,
      customer_name: "Crash Test Dummy"
    },
    user
  )

IO.puts("Ticket created: #{ticket.id} - Status: #{ticket.status}")

# Start Attendance
IO.puts("Attempting Start Attendance...")

try do
  case Tickets.start_attendance(ticket, user.id, user) do
    {:ok, updated} ->
      IO.puts("Success! Status: #{updated.status}")

    {:error, changeset_or_reason} ->
      IO.puts("Failed with error/changeset")
      IO.inspect(changeset_or_reason)
  end
rescue
  e ->
    IO.puts("CRASHED!")
    IO.inspect(e, label: "Exception")
    IO.inspect(System.stacktrace(), label: "Stacktrace")
catch
  kind, reason ->
    IO.puts("CAUGHT #{inspect(kind)}")
    IO.inspect(reason)
end
