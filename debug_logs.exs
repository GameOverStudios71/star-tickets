alias StarTickets.Repo
alias StarTickets.Audit.AuditLog
import Ecto.Query

query =
  from l in AuditLog,
    order_by: [desc: l.inserted_at],
    limit: 50

logs = Repo.all(query)

File.open("debug_output.txt", [:write], fn file ->
  IO.puts(file, "=== DUMPING 50 LOGS ===")

  Enum.each(logs, fn log ->
    IO.puts(
      file,
      "ID: #{log.id} | Action: #{log.action} | Type: #{log.resource_type} | ResID: #{log.resource_id}"
    )

    IO.inspect(file, log.details, [])
    IO.puts(file, "\n---")
  end)
end)

IO.puts("Logs written.")
