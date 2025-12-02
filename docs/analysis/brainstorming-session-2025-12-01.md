---
stepsCompleted: [1]
inputDocuments: []
session_topic: 'Sistema Completo star-tickets - Gestão de Senhas para Atendimento'
session_goals: 'Explorar e estruturar todos os componentes do sistema: interfaces, fluxos, inteligências, integrações e cronometragem'
selected_approach: 'Progressive Topic Exploration'
techniques_used: []
ideas_generated: []
context_file: ''
---

# Brainstorming Session Results - star-tickets

**Facilitador:** Zero
**Data:** 2025-12-01

---

## 📋 Visão Geral da Sessão

**Tópico:** Sistema completo de gestão de senhas para atendimento em estabelecimentos comerciais

**Objetivos:** 
- Explorar e detalhar todos os componentes do sistema
- Estruturar fluxos de usuário e lógicas de negócio
- Identificar inteligências necessárias
- Planejar integrações e cronometragem

---

## 🗂️ Estrutura de Tópicos Identificados

### 1. 🖥️ **TOTEM DE AUTOATENDIMENTO (Interface do Cliente)**
- Sistema de menus dinâmicos configuráveis via tabelas
- Navegação progressiva (Normal vs Preferencial → Submenus → Seleção de Serviços)
- Seleção múltipla de serviços
- Impressão de ticket com senha
- **Estimativa de Tempo:** Mostrar tempo médio de espera baseado em fila + duração média do serviço

### 2. 🎫 **SISTEMA DE SENHAS E PREFIXOS**
- Prefixos por tipo de serviço (ex: MAM001, OUT001)
- Lógica de geração:
  - Serviço único → Prefixo do serviço
  - Múltiplos serviços → Prefixo genérico (OUT)
- Senhas sequenciais por prefixo

### 3. 📺 **INFRAESTRUTURA DE TVs E CHAMADAS**
- **Cenários:**
  - 1 TV por sala de atendimento
  - 1 TV para múltiplas salas
  - TVs em diferentes recepções/salas de espera
- **Exibição:**
  - Senha + Nome do Paciente (nome em DESTAQUE)
  - Possibilidade de senha impressa diferente do serviço atual (correção da recepcionista)

### 4. 👥 **INTERFACE DA RECEPCIONISTA (1ª Recepção)**
- Dropdown para seleção da senha do ticket
- Vinculação: Senha → Nome do Paciente
- Visualização das seleções do totem
- **Modificação de Serviços:**
  - Correção de serviço errado
  - NÃO modifica senha impressa
  - Sistema usa nome do paciente na TV (resolve discrepância)
- Encaminhamento para sala de espera específica

### 5. 🏥 **INTERFACE DO PROFISSIONAL (Sala de Atendimento)**
- Seleção da sala onde está trabalhando
- Visualização da fila específica da sala
- Botão "Chamar Próximo"
- Botão "Finalizar Atendimento"
- Informar ao paciente para aguardar em outra sala (quando aplicável)

### 6. 📊 **ESTADOS E STATUS DO CLIENTE**
Fluxo completo de status:
1. **Retirou Ticket** - Cliente imprimiu no totem
2. **Cadastrado** - Recepcionista vinculou nome à senha
3. **Aguardando Atendimento** - Encaminhado para sala de espera específica
4. **Em Atendimento** - Profissional chamou e iniciou atendimento
5. **Finalizado** - Profissional concluiu atendimento

### 7. ⏱️ **SISTEMA DE CRONOMETRAGEM E INTELIGÊNCIA DE TEMPO**
**Rastreamento de tempos entre etapas:**
- Tempo: Impressão → Cadastro na recepção
- Tempo: Cadastro → Chamada para atendimento
- Tempo: Chamada → Início do atendimento
- Tempo: Duração do atendimento

**Inteligências baseadas em tempo:**
- Calcular tempo médio de espera por serviço
- Calcular duração média de atendimento por serviço
- **No Totem:** Mostrar estimativa de tempo considerando:
  - Quantidade de pessoas na fila à frente
  - Tempo médio do serviço selecionado
  - Histórico de tempos

### 8. 📅 **SISTEMA DE AGENDAMENTO E PRIORIZAÇÃO**
- **Integração com Sistema Externo:**
  - Busca periódica (a cada X tempo) dos agendamentos do dia
  - Sincronização de horários agendados
- **Lógica de Priorização:**
  - Serviços específicos seguem ordem de agendamento (não chegada)
  - Previne que quem chega cedo sem agendamento passe na frente de quem tem horário marcado
  - Exemplo: Agendado 9:15 não pode ser atendido depois de quem chegou às 9:00 sem agendamento

### 9. 🧠 **INTELIGÊNCIA DE MÚLTIPLOS ATENDIMENTOS**
**Problema:** Cliente com múltiplos serviços em salas diferentes

**Solução Inteligente:**
- Rastrear cliente com múltiplos serviços
- **Bloqueio de Chamada Simultânea:**
  - Cliente NÃO aparece na fila da Sala 2 enquanto está em atendimento na Sala 1
  - Só libera para próxima fila após "Finalizar Atendimento" na sala atual
- **Sequenciamento:**
  - Sistema define ordem de atendimento
  - Profissional informa ao cliente qual sala aguardar após finalizar
  - Sistema adiciona cliente na fila correta automaticamente

### 10. 🗄️ **ARQUITETURA DE DADOS E CONFIGURAÇÃO**
- **Menus Dinâmicos via Tabelas SQLite:**
  - Estrutura de menus e opções configurável
  - Navegação baseada em dados (não hardcoded)
- **Configurações:**
  - Tipos de serviço e prefixos
  - Mapeamento: Serviços → Salas
  - Mapeamento: TVs → Salas
  - Regras de agendamento por serviço

---

## ✅ Status Atual

**Contexto capturado e estruturado em 10 tópicos principais.**

Próximos passos sugeridos:
1. Validar se há tópicos adicionais que surgiram
2. Explorar cada tópico em profundidade
3. Identificar desafios técnicos e soluções
4. Priorizar features por MVP vs. Futuro

---

