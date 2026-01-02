# Logs do Totem - Rastreamento Completo da Jornada do Cliente

## 🎯 Eventos Rastreados

### 1. Início da Sessão
**Evento:** `TOTEM_SESSION_START`
- **Quando:** Cliente entra na tela do totem
- **Dados:**
  - `totem_session_id`: UUID único da sessão
  - `establishment_id`: ID do estabelecimento

### 2. Seleção de Serviços
**Evento:** `TOTEM_SERVICE_ADDED`
- **Quando:** Cliente clica em um serviço para adicionar
- **Dados:**
  - `totem_session_id`: UUID da sessão
  - `service_id`: ID do serviço adicionado
  - `service_name`: Nome do serviço
  - `total_selected`: Quantidade total de serviços selecionados
  - `selected_service_ids`: Lista de IDs de todos os serviços selecionados

### 3. Remoção de Serviços
**Evento:** `TOTEM_SERVICE_REMOVED`
- **Quando:** Cliente clica para remover um serviço da seleção
- **Dados:** (mesmos de `TOTEM_SERVICE_ADDED`)

### 4. Tela de Confirmação
**Evento:** `TOTEM_CONFIRMATION_SHOWN`
- **Quando:** Cliente clica em "Continuar" e vê a tela de confirmação
- **Dados:**
  - `totem_session_id`: UUID da sessão
  - `selected_services`: Lista completa de serviços (id + nome)
  - `total_services`: Quantidade total

### 5. Geração do Ticket (Tentativa)
**Evento:** `TOTEM_TICKET_GENERATION_STARTED`
- **Quando:** Cliente clica em "Gerar Senha" na confirmação
- **Dados:**
  - `totem_session_id`: UUID da sessão
  - `ticket_code`: Código da senha gerada (ex: "A001")
  - `services`: Lista de serviços
  - `establishment_id`: ID do estabelecimento

### 6. Ticket Impresso (Sucesso)
**Evento:** `TOTEM_TICKET_PRINTED`
- **Quando:** Ticket foi criado com sucesso no banco
- **Dados:**
  - `resource_type`: "Ticket"
  - `resource_id`: ID do ticket criado
  - `totem_session_id`: Link com a sessão do totem
  - `ticket_code`: Código da senha (ex: "A001")
  - `token`: Token UUID do ticket
  - `has_forms`: Boolean se tem formulário de WebCheckin
  - `url`: URL do QR Code

### 7. Falha na Geração (Erro)
**Evento:** `TOTEM_TICKET_GENERATION_FAILED`
- **Quando:** Erro ao criar o ticket no banco
- **Dados:**
  - `totem_session_id`: UUID da sessão
  - `ticket_code`: Código que tentou gerar
  - `errors`: Mensagem de erro

## 📊 Exemplo de Jornada Completa

```elixir
# 1. Cliente entra no totem
TOTEM_SESSION_START
  totem_session_id: "123e4567-e89b-12d3-a456-426614174000"
  establishment_id: 1

# 2. Cliente adiciona "Consulta"
TOTEM_SERVICE_ADDED
  service_id: 5
  service_name: "Consulta"
  total_selected: 1
  selected_service_ids: [5]

# 3. Cliente adiciona "Exame"
TOTEM_SERVICE_ADDED
  service_id: 8
  service_name: "Exame de Sangue"
  total_selected: 2
  selected_service_ids: [5, 8]

# 4. Cliente remove "Consulta" (mudou de ideia)
TOTEM_SERVICE_REMOVED
  service_id: 5
  service_name: "Consulta"
  total_selected: 1
  selected_service_ids: [8]

# 5. Cliente adiciona "Consulta" novamente
TOTEM_SERVICE_ADDED
  service_id: 5
  service_name: "Consulta"
  total_selected: 2
  selected_service_ids: [8, 5]

# 6. Cliente clica em "Continuar"
TOTEM_CONFIRMATION_SHOWN
  selected_services: [
    {id: 8, name: "Exame de Sangue"},
    {id: 5, name: "Consulta"}
  ]
  total_services: 2

# 7. Cliente clica em "Gerar Senha"
TOTEM_TICKET_GENERATION_STARTED
  ticket_code: "A042"
  services: [{id: 8, ...}, {id: 5, ...}]

# 8. Sistema cria ticket e imprime
TOTEM_TICKET_PRINTED
  resource_id: "123" (Ticket ID)
  ticket_code: "A042"
  token: "abc-def-ghi"
  has_forms: true
  url: "https://startickets.com/webcheckin/abc-def-ghi"
```

## 🔍 Como Consultar

### Ver jornada completa de uma sessão do totem:
```elixir
import Ecto.Query

session_id = "123e4567-e89b-12d3-a456-426614174000"

from(l in StarTickets.Audit.AuditLog,
  where: l.resource_id == ^session_id or 
         fragment("?->>'totem_session_id' = ?", l.details, ^session_id),
  order_by: [asc: l.inserted_at]
)
|> StarTickets.Repo.all()
```

### Ver estatísticas de uso do totem:
```elixir
from(l in StarTickets.Audit.AuditLog,
  where: l.action like "TOTEM_%",
  select: {l.action, count(l.id)},
  group_by: l.action
)
|> StarTickets.Repo.all()
```

### Descobrir qual senha um cliente pegou em uma sessão:
```elixir
from(l in StarTickets.Audit.AuditLog,
  where: l.action == "TOTEM_TICKET_PRINTED" and 
         fragment("?->>'totem_session_id' = ?", l.details, ^session_id),
  select: fragment("?->>'ticket_code'", l.details)
)
|> StarTickets.Repo.one()
```
