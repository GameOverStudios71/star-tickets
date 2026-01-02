# Script de Verificação do Sistema de Auditoria
# Execute com: mix run priv/repo/verify_audit.exs

alias StarTickets.{Repo, Audit, Accounts, Tickets}
alias StarTickets.Audit.AuditLog
import Ecto.Query

IO.puts("\n🔍 Verificando Sistema de Auditoria...\n")

# 1. Verificar se a tabela existe
IO.puts("1️⃣ Verificando tabela audit_logs...")
count = Repo.aggregate(AuditLog, :count, :id)
IO.puts("   ✅ Tabela existe! Total de logs: #{count}")

# 2. Criar um log de teste
IO.puts("\n2️⃣ Criando log de teste...")
{:ok, log} = Audit.log_action("TEST_ACTION", %{
  resource_type: "Test",
  resource_id: "123",
  details: %{message: "Sistema de auditoria funcionando!"}
})
IO.puts("   ✅ Log criado com ID: #{log.id}")

# 3. Verificar se o log foi gravado
IO.puts("\n3️⃣ Verificando gravação...")
retrieved = Repo.get(AuditLog, log.id)
if retrieved do
  IO.puts("   ✅ Log recuperado: #{retrieved.action}")
  IO.puts("   📋 Detalhes: #{inspect(retrieved.details)}")
else
  IO.puts("   ❌ Erro: Log não encontrado!")
end

# 4. Mostrar últimos 5 logs
IO.puts("\n4️⃣ Últimos 5 logs do sistema:")
recent_logs =
  from(l in AuditLog,
    order_by: [desc: l.inserted_at],
    limit: 5
  )
  |> Repo.all()

if Enum.empty?(recent_logs) do
  IO.puts("   ℹ️  Nenhum log encontrado (sistema novo)")
else
  Enum.each(recent_logs, fn log ->
    user_info = if log.user_id, do: " by User##{log.user_id}", else: ""
    IO.puts("   • #{log.action}#{user_info} - #{log.inserted_at}")
  end)
end

# 5. Estatísticas por tipo de ação
IO.puts("\n5️⃣ Estatísticas por tipo de ação:")
stats =
  from(l in AuditLog,
    select: {l.action, count(l.id)},
    group_by: l.action,
    order_by: [desc: count(l.id)]
  )
  |> Repo.all()

if Enum.empty?(stats) do
  IO.puts("   ℹ️  Sem estatísticas ainda")
else
  Enum.each(stats, fn {action, count} ->
    IO.puts("   • #{action}: #{count} eventos")
  end)
end

IO.puts("\n✅ Verificação concluída!")
IO.puts("📊 Total de logs no sistema: #{Repo.aggregate(AuditLog, :count, :id)}\n")
