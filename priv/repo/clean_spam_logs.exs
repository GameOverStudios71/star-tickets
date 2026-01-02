alias StarTickets.Repo
alias StarTickets.Audit.AuditLog
import Ecto.Query

# Delete logs where action is UI_INFO and details contain the recursive message
from(l in AuditLog,
  where: l.action == "UI_INFO" and
         fragment("?::text LIKE ?", l.details, "%audit_log_created%")
)
|> Repo.delete_all()
|> case do
  {count, _} -> IO.puts("Deleted #{count} spam logs.")
end
