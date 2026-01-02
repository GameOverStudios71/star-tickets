# Logs da TV - Rastreamento Completo de Exibições

## 🎯 Eventos Rastreados

### 1. Início da Sessão da TV
**Evento:** `TV_SESSION_START`
- **Quando:** TV conecta e carrega
- **Dados:**
  - `tv_session_id`: UUID único da sessão da TV
  - `establishment_id`: ID do estabelecimento
  - `tv_config`: Configuração da TV
    - `room_ids`: Lista de salas filtradas (se aplicável)
    - `all_rooms`: Boolean se mostra todas as salas
    - `news_enabled`: Se notícias estão habilitadas

### 2. Senha Recebida via PubSub
**Evento:** `TV_TICKET_RECEIVED`
- **Quando:** Recepcionista/Profissional chama uma senha e a TV recebe o evento
- **Dados:**
  - `tv_session_id`: UUID da sessão
  - `ticket_id`: ID do ticket
  - `ticket_code`: Código da senha (ex: "A042")
  - `room_id`: ID da sala
  - `status`: Status do ticket

### 3. Senha Filtrada (Não Exibida)
**Evento:** `TV_TICKET_FILTERED`
- **Quando:** TV recebe uma senha mas ela não passa pelo filtro de salas
- **Dados:**
  - `tv_session_id`: UUID da sessão
  - `ticket_id`: ID do ticket
  - `ticket_code`: Código da senha
  - `room_id`: ID da sala
  - `reason`: Motivo do filtro (ex: "room_filter")

### 4. Senha Exibida na Tela (Prioridade/TTS)
**Evento:** `TV_TICKET_DISPLAYED`
- **Quando:** Senha aparece na tela da TV com anúncio sonoro (TTS)
- **Dados:**
  - `tv_session_id`: UUID da sessão
  - `ticket_id`: ID do ticket
  - `ticket_code`: Código da senha
  - `room_name`: Nome da sala
  - `display_mode`: "incoming_with_tts"
  - `speech_text`: Texto falado (ex: "Senha A zero quarenta e dois, sala consulta")

### 5. Senha Exibida na Tela (Rotação)
**Evento:** `TV_TICKET_DISPLAYED`
- **Quando:** Senha aparece na rotação automática (sem TTS)
- **Dados:**
  - `tv_session_id`: UUID da sessão
  - `ticket_id`: ID do ticket
  - `ticket_code`: Código da senha
  - `room_name`: Nome da sala
  - `display_mode`: "rotation"
  - `rotation_index`: Posição na fila de rotação
  - `queue_size`: Tamanho total da fila

## 📊 Exemplo de Fluxo Completo

```elixir
# 1. TV Liga
TV_SESSION_START
  tv_session_id: "tv-abc-123"
  establishment_id: 1
  tv_config: {
    room_ids: [5, 8],  # Mostra apenas Sala 5 e 8
    all_rooms: false,
    news_enabled: true
  }

# 2. Recepcionista chama senha A042 na Sala 5
TV_TICKET_RECEIVED
  ticket_id: 123
  ticket_code: "A042"
  room_id: 5
  status: "CALLED_RECEPTION"

# 3. TV exibe a senha com TTS
TV_TICKET_DISPLAYED
  ticket_id: 123
  ticket_code: "A042"
  room_name: "Recepção"
  display_mode: "incoming_with_tts"
  speech_text: "Senha A zero quarenta e dois, sala Recepção"

# 4. Profissional chama senha B015 na Sala 12 (não monitorada)
TV_TICKET_FILTERED
  ticket_id: 124
  ticket_code: "B015"
  room_id: 12
  reason: "room_filter"  # TV não mostra salas fora do filtro

# 5. Após 10 segundos, TV rotaciona para próxima senha
TV_TICKET_DISPLAYED
  ticket_id: 125
  ticket_code: "A043"
  room_name: "Triagem"
  display_mode: "rotation"
  rotation_index: 1
  queue_size: 5
```

## 🔍 Como Consultar

### Ver todas as senhas exibidas em uma TV:
```elixir
import Ecto.Query

tv_session_id = "tv-abc-123"

from(l in StarTickets.Audit.AuditLog,
  where: l.resource_id == ^tv_session_id and l.action == "TV_TICKET_DISPLAYED",
  order_by: [asc: l.inserted_at]
)
|> StarTickets.Repo.all()
```

### Descobrir quantas vezes uma senha foi exibida:
```elixir
ticket_code = "A042"

from(l in StarTickets.Audit.AuditLog,
  where: l.action == "TV_TICKET_DISPLAYED" and 
         fragment("?->>'ticket_code' = ?", l.details, ^ticket_code)
)
|> StarTickets.Repo.aggregate(:count, :id)
```

### Ver senhas filtradas (não exibidas):
```elixir
from(l in StarTickets.Audit.AuditLog,
  where: l.action == "TV_TICKET_FILTERED",
  select: fragment("?->>'ticket_code'", l.details)
)
|> StarTickets.Repo.all()
```

### Estatísticas de uma sessão de TV:
```elixir
tv_session_id = "tv-abc-123"

from(l in StarTickets.Audit.AuditLog,
  where: l.resource_id == ^tv_session_id,
  select: {l.action, count(l.id)},
  group_by: l.action
)
|> StarTickets.Repo.all()

# Resultado exemplo:
# [
#   {"TV_SESSION_START", 1},
#   {"TV_TICKET_RECEIVED", 50},
#   {"TV_TICKET_DISPLAYED", 50},
#   {"TV_TICKET_FILTERED", 12}
# ]
```

## 🎯 Casos de Uso

### 1. Auditoria de Tempo de Resposta
Quanto tempo entre a senha ser chamada e ser exibida?
```elixir
# Compare TV_TICKET_RECEIVED com TV_TICKET_DISPLAYED
```

### 2. Verificar Filtros de Sala
Quantas senhas foram bloqueadas pelo filtro?
```elixir
# Count TV_TICKET_FILTERED
```

### 3. Análise de Rotação
Quantas senhas estão em rotação simultânea?
```elixir
# Veja queue_size nos logs de display_mode: "rotation"
```

### 4. TTS vs Rotação
Proporção de senhas anunciadas vs apenas exibidas?
```elixir
from(l in StarTickets.Audit.AuditLog,
  where: l.action == "TV_TICKET_DISPLAYED",
  select: {fragment("?->>'display_mode'", l.details), count(l.id)},
  group_by: fragment("?->>'display_mode'", l.details)
)
|> StarTickets.Repo.all()

# Resultado:
# [{"incoming_with_tts", 80}, {"rotation", 200}]
```
