# 🎫 StarTickets

Sistema completo de gestão de filas e atendimento para clínicas e estabelecimentos de saúde, desenvolvido com **Phoenix 1.8** e **LiveView**.

![Elixir](https://img.shields.io/badge/Elixir-1.15+-4B275F?logo=elixir)
![Phoenix](https://img.shields.io/badge/Phoenix-1.8-FD4F00?logo=phoenixframework)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-336791?logo=postgresql)
![License](https://img.shields.io/badge/License-Proprietary-red)

---

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Funcionalidades](#-funcionalidades)
- [Arquitetura](#-arquitetura)
- [Instalação](#-instalação)
- [Configuração](#-configuração)
- [Uso](#-uso)
- [API e Eventos](#-api-e-eventos)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Desenvolvimento](#-desenvolvimento)

---

## 🎯 Visão Geral

O **StarTickets** é uma solução multi-tenant para gestão de filas de atendimento, projetada especificamente para clínicas médicas e estabelecimentos de saúde ocupacional. O sistema oferece:

- **Totem de autoatendimento** para retirada de senhas
- **Painéis em tempo real** para recepção, profissionais e TVs de chamada
- **Web check-in** para pacientes preencherem formulários antes do atendimento
- **Formulários dinâmicos** para anamnese ocupacional
- **Gestão completa** de estabelecimentos, usuários, salas e serviços
- **Sentinel AI**: Inteligência artificial para monitoramento preditivo e detecção de anomalias
- **Notificações em Tempo Real**: Alertas via WhatsApp para administradores em caso de falhas críticas

---

## ✨ Funcionalidades

### 🖥️ Totem de Autoatendimento

| Recurso | Descrição |
|---------|-----------|
| **Menu Hierárquico** | Navegação em árvore configurável por estabelecimento |
| **Seleção de Serviços** | Paciente escolhe múltiplos serviços em uma única senha |
| **Atendimento Preferencial** | Opção separada com priorização automática |
| **QR Code** | Geração de QR Code para acompanhamento do status |
| **Tags Automáticas** | Categorização automática baseada no caminho de navegação |
| **Sons de Feedback** | Feedback sonoro nas interações |

### 👩‍💼 Painel de Recepção

| Recurso | Descrição |
|---------|-----------|
| **Lista de Tickets** | Visualização de todas as senhas aguardando atendimento |
| **Filtros Avançados** | Filtro por status, tags, serviços e período (12h/24h) |
| **Chamada de Senhas** | Chamar próxima senha com notificação em tempo real |
| **Seleção de Mesa** | Recepcionista seleciona em qual mesa está atendendo |
| **Priorização** | Senhas preferenciais destacadas e priorizadas |
| **Abas de Status** | Separação entre "Fila", "Em Atendimento" e "Finalizados" |
| **Web Check-in Status** | Visualização do progresso do web check-in do paciente |
| **Formulários** | Visualização e revisão de formulários preenchidos |

### 👨‍⚕️ Painel do Profissional

| Recurso | Descrição |
|---------|-----------|
| **Seleção de Sala** | Profissional indica em qual consultório está |
| **Fila Personalizada** | Lista apenas tickets com serviços compatíveis com a sala |
| **Chamada de Pacientes** | Chamar próximo paciente para atendimento |
| **Controle de Atendimento** | Iniciar e finalizar atendimentos |
| **Débito de Serviços** | Ao finalizar, remove serviços realizados; paciente retorna à fila se houver mais |
| **Histórico** | Visualização de atendimentos finalizados |

### 📺 Painel TV

| Recurso | Descrição |
|---------|-----------|
| **Display de Chamadas** | Exibição em tela grande para chamadas |
| **Text-to-Speech (TTS)** | Anúncio sonoro automático das chamadas |
| **Histórico Recente** | Lista das últimas chamadas |
| **Rotação Automática** | Alternância entre chamadas ativas |
| **Configurável** | Filtro por salas e serviços específicos |
| **Design Responsivo** | Layout otimizado para TVs e monitores |

### 📱 Web Check-in

| Recurso | Descrição |
|---------|-----------|
| **Acesso via QR Code** | Paciente acessa link pelo QR Code do ticket |
| **Formulários Dinâmicos** | Preenchimento de anamnese antes do atendimento |
| **Progresso Visual** | Indicador de progresso no preenchimento |
| **Validação em Tempo Real** | Validações instantâneas dos campos |
| **Múltiplas Seções** | Formulários divididos em seções navegáveis |

### 🔧 Painel Administrativo

#### Gestão de Usuários
- Criação, edição e exclusão de usuários
- Atribuição de roles: `admin`, `manager`, `reception`, `professional`, `totem`, `tv`
- Vinculação a cliente e estabelecimento
- Filtros por cliente, estabelecimento e busca

#### Gestão de Estabelecimentos
- Cadastro de unidades/filiais
- Código único por estabelecimento
- Endereço e telefone
- Status ativo/inativo

#### Gestão de Serviços
- Cadastro de serviços oferecidos
- Duração estimada em minutos
- Descrição detalhada
- Vinculação a formulários de anamnese

#### Gestão de Salas
- Tipos: `reception` (mesas), `professional` (consultórios), `both`
- Vinculação de serviços à sala
- Opção "Todos os Serviços"
- Controle de ocupação

#### Gestão de TVs
- Configuração de painéis de chamada
- Filtro por salas e serviços
- Usuário vinculado para autenticação automática

#### Gestão de Menus do Totem
- Estrutura hierárquica em árvore
- Ícones e descrições personalizáveis
- Vinculação de serviços aos itens do menu
- Configuração de "taggable" para categorização de tickets

#### Gestão de Formulários
- Criação de templates de formulário
- Seções organizadas
- Tipos de campos: texto, radio, checkbox, etc.
- Builder visual de formulários
- Vinculação a serviços específicos

### 🤖 Sentinel AI (Sistema de Inteligência)

O StarTickets conta com um "cérebro" autônomo chamado **Overseer** que monitora o sistema em tempo real.

| Recurso | Descrição |
|---------|-----------|
| **Serviço On-Demand** | Ativa automaticamente quando a página Sentinel é aberta, desativa quando fecha. Zero consumo em standby. |
| **Monitoramento de Conectividade** | Detecta instantaneamente se Totems, TVs ou Recepção ficam offline. |
| **Projeções Futuras** | Prevê próximos passos (ex: "Ticket criado deve ser chamado em 30min") e alerta se o prazo expirar. |
| **Detecção de Anomalias** | Identifica falhas críticas e desvios de fluxo operacional. |
| **Dispatcher Automático** | Envia alertas em tempo real para o WhatsApp dos administradores. |
| **Indicador de Status** | Header mostra ACTIVE/STANDBY com animação visual em tempo real. |

### 🔔 Centro de Alertas & WhatsApp

Sistema avançado de notificação para garantir alta disponibilidade.

- **Painel de Notificações**: Tela `/admin/notifications` com todos os alertas críticos (Erros e Avisos).
- **Integração WhatsApp**:
  - Envio automático para **Admins e Managers** com telefone cadastrado.
  - Alertas de Crash, Erro de Debug, Queda de Conexão e **Rate Limit Excedido**.
  - Alertas nominais (ex: "Totem da Recepção 2 caiu").
- **Sincronização Total**: Tudo que é enviado por WhatsApp também aparece na caixa de notificações.
- **Auditoria Completa**: Logs detalhados de todas as ações ("Paranoid Mode") para rastreabilidade total.

### 🔐 Autenticação e Autorização

| Recurso | Descrição |
|---------|-----------|
| **Login por Email/Senha** | Autenticação tradicional |
| **Login por Username** | Suporte a login por nome de usuário |
| **Magic Links** | Login sem senha via email |
| **Confirmação de Email** | Fluxo de confirmação de conta |
| **Reset de Senha** | Recuperação de acesso |
| **Impersonation** | Administradores podem assumir identidade de outros usuários |
| **Seleção de Estabelecimento** | Usuários admin podem alternar entre estabelecimentos |
| **Controle por Roles** | Acesso às funcionalidades baseado em papel do usuário |

### 📊 Recursos Adicionais

- **Multi-tenant**: Isolamento completo de dados por cliente
- **Real-time**: Atualizações instantâneas via Phoenix PubSub
- **Responsivo**: Interface adaptável a diferentes dispositivos
- **Acessível**: Suporte a atendimento preferencial
- **Audit Logs**: Rastreabilidade completa de ações e diffs de dados

### 🛡️ Resiliência e Proteção

O StarTickets implementa um conjunto completo de medidas de resiliência inspiradas em casos reais de sistemas de alta carga (ex: Mega da Virada 2025).

#### DebounceSubmit (Proteção contra Cliques Múltiplos)

| Recurso | Descrição |
|---------|-----------|
| **JS Hook Global** | Hook `DebounceSubmit` em `assets/js/app.js` que previne cliques múltiplos |
| **Feedback Visual** | Botão desabilita + spinner aparece durante processamento |
| **Auto-reset** | Reativa automaticamente após resposta do servidor ou timeout de 10s |
| **Cobertura Total** | 30+ botões críticos protegidos em todas as páginas |

**Páginas Protegidas:**
- Totem: CONFIRMAR E GERAR SENHA
- Recepção: CHAMAR, INICIAR, FINALIZAR
- Profissional: CHAMAR, INICIAR, FINALIZAR
- Dispositivos: Desconectar, Desconectar Outros
- Admin: Todos os botões de exclusão (Users, TVs, Rooms, Establishments, Services, Forms, Sentinel, TotemMenus, FormBuilder)

#### Rate Limiting (Proteção contra Spam)

| Pipeline | Limite | Rotas |
|----------|--------|-------|
| `rate_limit_public` | 60 req/min | Landing, TicketStatus, WebCheckin |
| `rate_limit_auth` | 30 req/min | Login, Registro |
| `rate_limit_general` | 100 req/min | Dashboard, Admin, Reception, Professional |
| `rate_limit_totem` | 20 req/min | Totem (disponível para uso) |

**Implementação:**
- **Hammer** library com backend ETS para contagem de requisições
- **Plug customizado** `StarTicketsWeb.Plugs.RateLimiter`
- Resposta HTTP 429 com JSON de erro quando limite é excedido
- **Notificação automática** via WhatsApp para admins/managers quando limite é excedido

#### Connection Pool Tuning

Configurações otimizadas em `config/runtime.exs`:

```elixir
config :star_tickets, StarTickets.Repo,
  pool_size: 20,           # Aumentado de 10 para 20
  queue_target: 500,       # ms - tempo alvo na fila
  queue_interval: 1000,    # ms - intervalo de verificação
  timeout: 15_000          # ms - timeout de checkout
```

#### Offline Indicator (Detecção de Desconexão)

| Recurso | Descrição |
|---------|-----------|
| **Estilo Premium Acrylic** | Visual com blur, shadows e glow |
| **Heartbeat Animation** | Indica tentativa de reconexão |
| **Botão de Reporte** | Link direto para WhatsApp do admin |
| **Cobertura Global** | Injetado no `root.html.heex` |

#### Presença em Tempo Real

| Recurso | Descrição |
|---------|-----------|
| **PresenceHook** | Rastreia usuários conectados via `Phoenix.Presence` |
| **Contador no Dashboard** | Exibe número de usuários online com avatares |
| **Topic Global** | `system:presence` para broadcast de status |

#### Arquitetura de Resiliência

```
┌──────────────────────────────────────────────────────────────────────┐
│                        FRONTEND (Browser)                             │
├──────────────────────────────────────────────────────────────────────┤
│  DebounceSubmit Hook     │  Offline Indicator     │  Presença         │
│  (Previne cliques)       │  (Detecta queda)       │  (Status online)  │
└──────────────────────────────────────────────────────────────────────┘
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│                          ROUTER (Elixir)                              │
├──────────────────────────────────────────────────────────────────────┤
│  rate_limit_auth (30/min)  │  rate_limit_general (100/min)           │
│  (Login, Registro)         │  (Todas as rotas autenticadas)          │
└──────────────────────────────────────────────────────────────────────┘
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│                        DATABASE (PostgreSQL)                          │
├──────────────────────────────────────────────────────────────────────┤
│  pool_size: 20  │  queue_target: 500ms  │  timeout: 15s              │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Arquitetura

### Modelo de Dados

```
┌─────────────────────────────────────────────────────────────────┐
│                           CLIENT                                 │
│  (Multi-tenant: Pro Ocupacional, etc.)                          │
└─────────────────────────────────────────────────────────────────┘
         │
         ├──────────────────────────────────────┐
         │                                      │
         ▼                                      ▼
┌─────────────────┐                    ┌─────────────────┐
│  ESTABLISHMENT  │                    │     SERVICE     │
│  (Freguesia,    │                    │  (Ultrassom,    │
│   Santana...)   │                    │   Raio-X...)    │
└─────────────────┘                    └─────────────────┘
         │                                      │
         ├───────────────┬──────────────────────┤
         │               │                      │
         ▼               ▼                      ▼
┌─────────────┐  ┌─────────────┐      ┌─────────────────┐
│    USER     │  │    ROOM     │      │   FORM_TEMPLATE │
│ (Roles:     │  │ (Salas e    │      │   (Anamnese)    │
│ admin, etc.)│  │  Mesas)     │      └─────────────────┘
└─────────────┘  └─────────────┘               │
       ▲                │                      ▼
       │ (Alerts)┌───────────────────────┴───────────────────────────┐
       │         │                      TICKET                        │
┌─────────────┐  │  (Senha com status, serviços, tags, formulários)  │
│  OVERSEER   │◄─┤                                                   │
│ (Sentinel)  │  └───────────────────────────────────────────────────┘
└─────────────┘             (Monitors Events via PubSub)
```

### Status do Ticket

```
WAITING_RECEPTION    →  Aguardando na fila da recepção
       ↓
CALLED_RECEPTION     →  Chamado pela recepção
       ↓
IN_RECEPTION         →  Em atendimento na recepção
       ↓
WAITING_PROFESSIONAL →  Aguardando profissional
       ↓
CALLED_PROFESSIONAL  →  Chamado pelo profissional
       ↓
IN_ATTENDANCE        →  Em atendimento com profissional
       ↓
FINISHED             →  Atendimento concluído
```

---

## 🚀 Instalação

### Pré-requisitos

- Elixir 1.15+
- Erlang/OTP 26+
- PostgreSQL 14+
- Node.js 18+ (para assets)

### Passos

```bash
# Clonar o repositório
git clone https://github.com/seu-usuario/star-tickets.git
cd star-tickets

# Instalar dependências e configurar banco de dados
mix setup

# Iniciar o servidor
mix phx.server
```

O sistema estará disponível em [http://localhost:4000](http://localhost:4000).

---

## ⚙️ Configuração

### Variáveis de Ambiente (Produção)

```bash
# Banco de Dados
DATABASE_URL="ecto://user:pass@host/star_tickets_prod"

# Servidor
PHX_HOST="seu-dominio.com"
PHX_PORT="4000"
SECRET_KEY_BASE="sua-chave-secreta-64-chars"

# Email (Swoosh)
SMTP_HOST="smtp.exemplo.com"
SMTP_PORT="587"
SMTP_USERNAME="usuario"
SMTP_PASSWORD="senha"
```

### Desenvolvimento

Configure `config/dev.exs`:

```elixir
config :star_tickets, StarTickets.Repo,
  username: "postgres",
  password: "sua_senha",
  hostname: "localhost",
  database: "star_tickets_dev"
```

---

## 📖 Uso

### Usuários de Teste (Seeds)

Após rodar `mix setup`, os seguintes usuários estarão disponíveis:

| Email | Senha | Role | Descrição |
|-------|-------|------|-----------|
| `admin@proocupacional.com.br` | `minhasenha123` | admin | Acesso total |
| `recepcao@proocupacional.com.br` | `minhasenha123` | reception | Painel da recepção |
| `gerente.freguesia@proocupacional.com.br` | `minhasenha123` | manager | Gerente de unidade |
| `medico1.freguesia@proocupacional.com.br` | `minhasenha123` | professional | Médico |
| `medico2.freguesia@proocupacional.com.br` | `minhasenha123` | professional | Médica |
| `tv.freguesia@proocupacional.com.br` | `minhasenha123` | tv | Painel TV |

### Fluxo Típico de Uso

1. **Admin** configura estabelecimentos, serviços, salas e menus
2. **Paciente** usa o Totem (`/totem`) para retirar senha
3. **Recepcionista** acessa `/reception` para chamar e atender
4. **Profissional** acessa `/professional` para realizar consultas
5. **TV** exibe chamadas em `/tv` no painel público

### Rotas Principais

| Rota | Descrição | Acesso |
|------|-----------|--------|
| `/` | Landing page | Público |
| `/users/log-in` | Login | Público |
| `/totem` | Totem de autoatendimento | Autenticado (totem) |
| `/reception` | Painel da recepção | Autenticado (reception+) |
| `/professional` | Painel do profissional | Autenticado |
| `/tv` | Painel de chamadas TV | Autenticado (tv) |
| `/sentinel` | Painel de Monitoramento AI | Admin |
| `/admin/notifications` | Centro de Alertas | Admin |
| `/dashboard` | Dashboard geral | Autenticado |
| `/admin/*` | Área administrativa | Admin/Manager |
| `/ticket/:token` | Status do ticket | Público |
| `/webcheckin/:token` | Web check-in | Público |

---

## 📡 API e Eventos

### PubSub Topics

O sistema utiliza Phoenix PubSub para comunicação em tempo real:

```elixir
# Topic principal de tickets
"tickets"

# Eventos emitidos
{:ticket_created, ticket}     # Nova senha criada
{:ticket_updated, ticket}     # Ticket atualizado
{:ticket_called, ticket}      # Senha chamada (para TV)

# Topic de recepção
"reception"

# Eventos
{:room_updated, room}         # Sala/mesa atualizada
{:room_created, room}         # Nova sala criada
```

### Subscriptions (Live Views)

```elixir
# Subscrever a atualizações
Tickets.subscribe()
Reception.subscribe()
```

---

## 📁 Estrutura do Projeto

```
star-tickets/
├── assets/                    # Assets JavaScript/CSS
│   ├── js/
│   │   └── app.js            # JavaScript principal
│   └── css/
│       └── app.css           # Tailwind CSS
├── config/                    # Configurações
│   ├── config.exs            # Config geral
│   ├── dev.exs               # Desenvolvimento
│   ├── prod.exs              # Produção
│   └── runtime.exs           # Runtime (env vars)
├── lib/
│   ├── star_tickets/         # Contextos de negócio
│   │   ├── accounts/         # Schemas de contas
│   │   │   ├── client.ex
│   │   │   ├── establishment.ex
│   │   │   ├── user.ex
│   │   │   ├── service.ex
│   │   │   ├── room.ex
│   │   │   ├── tv.ex
│   │   │   └── totem_menu.ex
│   │   ├── tickets/          # Schemas de tickets
│   │   │   └── ticket.ex
│   │   ├── forms/            # Sistema de formulários
│   │   │   ├── form_template.ex
│   │   │   ├── form_section.ex
│   │   │   ├── form_field.ex
│   │   │   └── form_response.ex
│   │   ├── accounts.ex       # Context de contas
│   │   ├── tickets.ex        # Context de tickets
│   │   ├── forms.ex          # Context de formulários
│   │   └── reception.ex      # Context de recepção
│   └── star_tickets_web/     # Camada Web
│       ├── components/       # Componentes reutilizáveis
│       │   ├── core_components.ex
│       │   └── layouts.ex
│       ├── controllers/      # Controllers tradicionais
│       │   └── user_session_controller.ex
│       ├── live/             # LiveViews
│       │   ├── admin/        # Área administrativa
│       │   │   ├── users_live.ex
│       │   │   ├── establishments_live.ex
│       │   │   ├── services_live.ex
│       │   │   ├── rooms_live.ex
│       │   │   ├── tvs_live.ex
│       │   │   ├── totem_menus_live.ex
│       │   │   ├── forms_live.ex
│       │   │   └── form_builder_live.ex
│       │   ├── public/       # Área pública
│       │   │   ├── ticket_status_live.ex
│       │   │   └── web_checkin_live.ex
│       │   ├── reception_live.ex
│       │   ├── professional_live.ex
│       │   ├── totem_live.ex
│       │   ├── tv_live.ex
│       │   └── dashboard_live.ex
│       ├── router.ex         # Rotas
│       └── user_auth.ex      # Autenticação
├── priv/
│   ├── repo/
│   │   ├── migrations/       # Migrações do banco
│   │   └── seeds.exs         # Seeds iniciais
│   └── static/               # Arquivos estáticos
├── test/                     # Testes
├── mix.exs                   # Dependências
└── AGENTS.md                 # Guia para agentes de IA
```

---

## 🛠️ Desenvolvimento

### Comandos Úteis

```bash
# Setup completo
mix setup

# Iniciar servidor de desenvolvimento
mix phx.server

# Iniciar com IEx
iex -S mix phx.server

# Rodar testes
mix test

# Rodar testes com coverage
mix test --cover

# Antes de commit (compila, formata, testa)
mix precommit

# Resetar banco de dados
mix ecto.reset

# Criar migração
mix ecto.gen.migration nome_da_migracao

# Rodar migrações
mix ecto.migrate
```

### Stack Tecnológica

| Tecnologia | Versão | Uso |
|------------|--------|-----|
| **Elixir** | ~> 1.15 | Linguagem principal |
| **Phoenix** | ~> 1.8.3 | Framework web |
| **Phoenix LiveView** | ~> 1.1.0 | Interfaces reativas |
| **Ecto** | ~> 3.13 | ORM/Query builder |
| **PostgreSQL** | 14+ | Banco de dados |
| **Tailwind CSS** | v4 | Estilização |
| **esbuild** | ~> 0.10 | Bundler JavaScript |
| **Bcrypt** | ~> 3.0 | Hash de senhas |
| **Swoosh** | ~> 1.16 | Envio de emails |
| **Req** | ~> 0.5 | Cliente HTTP |
| **EQRCode** | ~> 0.1.10 | Geração de QR Codes |

---

## 📄 Licença

Proprietary - Todos os direitos reservados.

---

## 🤝 Suporte

Para suporte técnico, entre em contato com a equipe de desenvolvimento.
