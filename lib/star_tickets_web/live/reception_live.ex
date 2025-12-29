defmodule StarTicketsWeb.ReceptionLive do
  use StarTicketsWeb, :live_view

  alias StarTicketsWeb.ImpersonationHelpers
  alias StarTickets.Reception
  alias StarTickets.Tickets
  alias StarTickets.Accounts
  alias StarTickets.Forms
  alias StarTickets.Repo

  @impl true
  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    socket =
      socket
      |> assign(impersonation_assigns)
      |> assign(:current_user, socket.assigns.current_scope.user)
      # active, finished
      |> assign(:active_tab, "active")
      |> assign(:selected_desk_id, nil)
      |> assign(:selected_ticket, nil)
      # New state for modal
      |> assign(:reviewing_ticket, nil)
      # ["insurance", "private", "priority"]
      |> assign(:filter_type, [])
      # [service_id, ...]
      |> assign(:filter_services, [])
      |> load_desks()
      |> load_tickets()
      |> load_tickets()

    if connected?(socket) do
      Tickets.subscribe()
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:ticket_created, ticket}, socket) do
    # Only append if relevant to current filter? For now reload or append.
    # Simple strategy: prepend to all_tickets and re-filter

    # Needs preloads (services, desk) for proper display
    ticket = Repo.preload(ticket, [:services, :reception_desk])

    all_tickets = [ticket | socket.assigns.all_tickets]

    socket =
      socket
      |> assign(:all_tickets, all_tickets)
      |> refresh_tickets_view()
      |> put_flash(:info, "Nova senha: #{ticket.display_code}")

    {:noreply, socket}
  end

  def handle_info({:ticket_updated, ticket}, socket) do
    # Needs preloads
    ticket = Repo.preload(ticket, [:services, :reception_desk])

    all_tickets =
      Enum.map(socket.assigns.all_tickets, fn t ->
        if t.id == ticket.id, do: ticket, else: t
      end)

    socket =
      socket
      |> assign(:all_tickets, all_tickets)
      |> update_selected_ticket(all_tickets)
      |> update_reviewing_ticket(ticket)
      |> refresh_tickets_view()

    {:noreply, socket}
  end

  defp update_reviewing_ticket(socket, ticket) do
    if socket.assigns.reviewing_ticket && socket.assigns.reviewing_ticket.id == ticket.id do
      # Keep form responses if they were loaded?
      # Broadcast usually sends just the ticket. We might loose form responses if we just replace.
      # Ideally we merge or just update status.
      # For now, let's re-load full data if we are reviewing it.
      full_ticket = Tickets.load_full_data(ticket)
      assign(socket, :reviewing_ticket, full_ticket)
    else
      socket
    end
  end

  defp load_desks(socket) do
    if socket.assigns.selected_establishment_id do
      desks = Reception.list_desks(socket.assigns.selected_establishment_id)
      assign(socket, :desks, desks)
    else
      assign(socket, :desks, [])
    end
  end

  defp load_tickets(socket) do
    if socket.assigns.selected_establishment_id do
      all_tickets = Tickets.list_reception_tickets(socket.assigns.selected_establishment_id)

      # Filter and assign
      filtered_tickets =
        filter_tickets(all_tickets, socket.assigns.active_tab, socket.assigns.filter_type)

      socket
      # Keep raw list for updates
      |> assign(:all_tickets, all_tickets)
      |> assign(:tickets, filtered_tickets)
      |> update_selected_ticket(all_tickets)
    else
      socket
      |> assign(:all_tickets, [])
      |> assign(:tickets, [])
    end
  end

  defp update_selected_ticket(socket, all_tickets) do
    if socket.assigns.selected_ticket do
      # Refresh selected ticket data
      updated = Enum.find(all_tickets, &(&1.id == socket.assigns.selected_ticket.id))
      assign(socket, :selected_ticket, updated)
    else
      socket
    end
  end

  defp filter_tickets(tickets, tab, _filters) do
    # 1. Filter by Tab
    filtered =
      case tab do
        "active" ->
          Enum.filter(
            tickets,
            &(&1.status in ["WAITING_RECEPTION", "CALLED_RECEPTION", "IN_RECEPTION"])
          )

        "finished" ->
          Enum.filter(
            tickets,
            &(&1.status not in ["WAITING_RECEPTION", "CALLED_RECEPTION", "IN_RECEPTION"])
          )

        _ ->
          tickets
      end

    # 2. Advanced filters (TODO: Implement type filters)
    filtered
  end

  @impl true
  def handle_event("select_desk", %{"desk_id" => desk_id}, socket) do
    id = if desk_id == "", do: nil, else: String.to_integer(desk_id)

    socket =
      socket
      |> assign(:selected_desk_id, id)
      |> push_event("save_desk_preference", %{id: id})

    {:noreply, socket}
  end

  def handle_event("restore_desk_preference", %{"id" => id}, socket) do
    id = String.to_integer(id)

    # Verify if desk exists in current list (security check)
    valid_id? = Enum.any?(socket.assigns.desks, &(&1.id == id))

    socket =
      if valid_id? do
        assign(socket, :selected_desk_id, id)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    socket =
      socket
      |> assign(:active_tab, tab)
      # Clear selection on tab switch
      |> assign(:selected_ticket, nil)
      |> refresh_tickets_view()

    {:noreply, socket}
  end

  def handle_event("select_ticket", %{"id" => id}, socket) do
    ticket = Enum.find(socket.assigns.all_tickets, &(&1.id == String.to_integer(id)))
    # Start WebCheckin review if needed?
    {:noreply, assign(socket, :selected_ticket, ticket)}
  end

  def handle_event("call_ticket", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id)

    case Tickets.update_ticket_status(ticket, "CALLED_RECEPTION") do
      {:ok, updated_ticket} ->
        # Also assign to desk if not set?
        if socket.assigns.selected_desk_id do
          Tickets.assign_ticket_to_desk(updated_ticket, socket.assigns.selected_desk_id)
        end

        {:noreply,
         socket
         |> put_flash(:info, "Senha chamada com sucesso!")
         # Reload to reflect changes
         |> load_tickets()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao chamar senha.")}
    end
  end

  def handle_event("start_attendance", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id)
    {:ok, _} = Tickets.update_ticket_status(ticket, "IN_RECEPTION")
    {:noreply, load_tickets(socket)}
  end

  def handle_event("finish_ticket", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id)
    # Default "Finish" behavior
    {:ok, _} = Tickets.update_ticket_status(ticket, "WAITING_PROFESSIONAL")
    {:noreply, load_tickets(socket)}
  end

  def handle_event("open_review", %{"id" => id}, socket) do
    # Load full data (answers, files) only when needed
    ticket = Tickets.get_ticket!(id) |> Tickets.load_full_data()
    {:noreply, assign(socket, :reviewing_ticket, ticket)}
  end

  def handle_event("close_review", _, socket) do
    {:noreply, assign(socket, :reviewing_ticket, nil)}
  end

  def handle_event("mark_webcheckin_reviewed", %{"id" => id}, socket) do
    {:ok, _updated_ticket} =
      Tickets.update_ticket(Tickets.get_ticket!(id), %{webcheckin_status: "REVIEWED"})

    # Reload main list and close modal
    {:noreply,
     socket
     |> assign(:reviewing_ticket, nil)
     |> load_tickets()}
  end

  defp refresh_tickets_view(socket) do
    filtered =
      filter_tickets(
        socket.assigns.all_tickets,
        socket.assigns.active_tab,
        socket.assigns.filter_type
      )

    assign(socket, :tickets, filtered)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-20">
      <%!-- Web Check-in Review Modal --%>
      <%= if @reviewing_ticket do %>
        <div class="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-md p-6">
           <div class="bg-slate-900 border border-white/20 rounded-2xl w-full max-w-4xl max-h-full overflow-hidden flex flex-col shadow-2xl animate-in fade-in zoom-in duration-200">
              <div class="p-6 border-b border-white/10 flex justify-between items-center bg-gradient-to-r from-emerald-900/40 to-slate-900">
                 <div>
                    <h2 class="text-2xl font-bold text-white flex items-center gap-2">
                       📋 Revisão Web Check-in
                       <span class="text-sm bg-black/40 px-2 py-1 rounded text-white/60"><%= @reviewing_ticket.display_code %></span>
                    </h2>
                    <p class="text-white/50 text-sm">Respostas do cliente</p>
                 </div>
                 <button class="text-white/60 hover:text-white transition-colors text-2xl" phx-click="close_review">&times;</button>
              </div>

              <div class="flex-1 overflow-y-auto p-6 space-y-6">
                 <%!-- Customer Info --%>
                 <div class="grid grid-cols-2 gap-4">
                    <div class="bg-white/5 p-4 rounded-xl border border-white/10">
                       <label class="block text-xs uppercase tracking-wider text-white/40 mb-1">Nome Informado</label>
                       <div class="text-white font-medium text-lg"><%= @reviewing_ticket.customer_name || "Não informado" %></div>
                    </div>
                    <div class="bg-white/5 p-4 rounded-xl border border-white/10">
                       <label class="block text-xs uppercase tracking-wider text-white/40 mb-1">Status Web Check-in</label>
                       <div class="text-emerald-400 font-bold"><%= @reviewing_ticket.webcheckin_status || "PENDENTE" %></div>
                    </div>
                 </div>

                 <%!-- Forms Responses --%>
                 <%= if Enum.empty?(@reviewing_ticket.form_responses) do %>
                    <div class="text-center py-12 text-white/30 border-2 border-dashed border-white/10 rounded-xl">
                       Nenhuma resposta encontrada.
                    </div>
                 <% else %>
                    <div class="space-y-4">
                       <h3 class="text-white font-bold border-b border-white/10 pb-2">Respostas do Formulário</h3>
                       <%= for response <- @reviewing_ticket.form_responses do %>
                          <div class="bg-white/5 p-4 rounded-lg border border-white/5 hover:bg-white/10 transition-colors">
                             <div class="text-emerald-400 text-sm font-bold mb-1"><%= response.form_field.label %></div>
                             <div class="text-white text-base"><%= response.value %></div>
                          </div>
                       <% end %>
                    </div>
                 <% end %>
              </div>

              <div class="p-6 border-t border-white/10 bg-black/20 flex justify-end gap-3">
                 <button class="px-6 py-3 text-white/70 hover:text-white font-medium transition-colors" phx-click="close_review">Cancelar</button>
                 <button class="px-6 py-3 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg shadow-lg shadow-emerald-900/20 active:scale-95 transition-all" phx-click="mark_webcheckin_reviewed" phx-value-id={@reviewing_ticket.id}>
                    ✅ Marcar como Revisado
                 </button>
              </div>
           </div>
        </div>
      <% end %>

      <%!-- Custom Header Overlay used via AppHeader component --%>
      <.app_header
         title="Recepção / Triagem"
         show_home={true}
         home_path={~p"/dashboard"}
         current_scope={@current_scope}
      >
         <:right>
            <%!-- Desk Selector with Hook and Green Acrylic Style --%>
            <div id="desk-selector" phx-hook="DeskPreference"
                 class={"flex items-center gap-3 px-4 py-2 rounded-lg transition-all shadow-lg " <>
                if(@selected_desk_id,
                   do: "bg-emerald-600/90 backdrop-blur-md ring-2 ring-emerald-400 border border-emerald-300/50 shadow-emerald-500/30",
                   # Unselected: Dark Green/Black Gradient to be "Green" but inactive
                   else: "bg-gradient-to-br from-emerald-950/80 to-black/80 border border-emerald-500/20 ring-1 ring-emerald-500/10")}>
                <span class="text-white font-medium">
                   <%= if @selected_desk_id, do: "✅ Mesa Ativa:", else: "🪑 Minha Mesa:" %>
                </span>
                <form phx-change="select_desk" class="m-0">
                  <select name="desk_id" class={"bg-black/20 text-white border-none rounded focus:ring-2 focus:ring-emerald-400 cursor-pointer min-w-[150px] transition-all " <> if(@selected_desk_id, do: "font-bold text-emerald-100", else: "")}>
                    <option value="">Selecione...</option>
                    <%= for desk <- @desks do %>
                      <option value={desk.id} selected={@selected_desk_id == desk.id}><%= desk.name %></option>
                    <% end %>
                  </select>
                </form>
            </div>
         </:right>
      </.app_header>

      <div class="flex-1 grid grid-cols-12 gap-6 p-6 overflow-hidden h-[calc(100vh-80px)]">
         <%!-- Left Column: List & Filters --%>
         <div class="col-span-4 flex flex-col gap-4 relative h-full">
            <%= unless @selected_desk_id do %>
              <div class="absolute inset-0 z-20 bg-black/60 backdrop-blur-sm rounded-2xl flex flex-col items-center justify-center text-center p-6 border border-white/10 shadow-2xl">
                 <div class="text-4xl mb-4">🪑</div>
                 <h3 class="text-xl font-bold text-white mb-2">Selecione sua mesa</h3>
                 <p class="text-white/60">Para iniciar o atendimento, selecione sua posição de trabalho no topo da tela.</p>
              </div>
            <% end %>

            <%!-- Filters --%>
            <div class={"bg-white/5 border border-white/10 rounded-2xl p-4 backdrop-blur-md transition-all " <> if(!@selected_desk_id, do: "opacity-30 blur-[2px]", else: "")}>
               <h3 class="text-white font-medium mb-3 flex items-center justify-between cursor-pointer group">
                  <span>🔎 Filtros</span>
                  <span class="text-xs bg-white/10 px-2 py-1 rounded text-white/70 group-hover:bg-white/20">Expandir</span>
               </h3>
               <%!-- Basic Checks --%>
               <div class="grid grid-cols-2 gap-2 text-sm text-white/80">
                  <label class="flex items-center gap-2 cursor-pointer hover:text-white"><input type="checkbox" class="rounded bg-white/10 border-white/20 text-emerald-500 focus:ring-0"> Convênio</label>
                  <label class="flex items-center gap-2 cursor-pointer hover:text-white"><input type="checkbox" class="rounded bg-white/10 border-white/20 text-emerald-500 focus:ring-0"> Particular</label>
                  <label class="flex items-center gap-2 cursor-pointer hover:text-white"><input type="checkbox" class="rounded bg-white/10 border-white/20 text-emerald-500 focus:ring-0"> Preferencial</label>
               </div>
            </div>

            <%!-- Ticket List With Tabs --%>
            <div class={"flex-1 flex flex-col bg-white/5 border border-white/10 rounded-2xl backdrop-blur-md overflow-hidden transition-all " <> if(!@selected_desk_id, do: "opacity-30 blur-[2px]", else: "")}>
               <div class="flex border-b border-white/10">
                  <button class={"flex-1 py-3 text-sm font-medium transition-colors hover:bg-white/5 " <> if(@active_tab == "active", do: "text-white bg-white/10 border-b-2 border-emerald-400", else: "text-white/50")} phx-click="set_tab" phx-value-tab="active">
                    ⏳ Aguardando
                  </button>
                  <button class={"flex-1 py-3 text-sm font-medium transition-colors hover:bg-white/5 " <> if(@active_tab == "finished", do: "text-white bg-white/10 border-b-2 border-emerald-400", else: "text-white/50")} phx-click="set_tab" phx-value-tab="finished">
                    ✅ Finalizados
                  </button>
               </div>

               <div class="flex-1 overflow-y-auto p-2 space-y-2 custom-scrollbar">
                  <%= if Enum.empty?(@tickets) do %>
                    <div class="h-full flex flex-col items-center justify-center text-white/30">
                       <div class="text-4xl mb-2">📭</div>
                       <p>Nenhuma senha na fila</p>
                    </div>
                  <% else %>
                     <%= for ticket <- @tickets do %>
                        <div class={"bg-white/5 border border-white/10 p-3 rounded-xl hover:bg-white/10 cursor-pointer transition-all group active:scale-[0.98] " <> if(@selected_ticket && @selected_ticket.id == ticket.id, do: "bg-emerald-500/10 border-emerald-500/50 ring-1 ring-emerald-500/30", else: "")} phx-click="select_ticket" phx-value-id={ticket.id}>
                           <div class="flex justify-between items-start mb-1">
                              <span class="text-xl font-bold text-white"><%= ticket.display_code %></span>
                              <span class={"text-xs font-bold px-2 py-0.5 rounded border " <>
                                 case ticket.status do
                                    "WAITING_RECEPTION" -> "bg-amber-500/20 text-amber-300 border-amber-500/30"
                                    "CALLED_RECEPTION" -> "bg-blue-500/20 text-blue-300 border-blue-500/30"
                                    "IN_RECEPTION" -> "bg-emerald-500/20 text-emerald-300 border-emerald-500/30"
                                    _ -> "bg-slate-500/20 text-slate-300 border-slate-500/30"
                                 end
                              }><%= ticket.status %></span>
                           </div>
                           <div class="flex items-center gap-2 mb-2">
                              <%= if ticket.is_priority do %>
                                 <span class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30">PREFERENCIAL</span>
                              <% end %>
                              <%= if ticket.health_insurance_name do %>
                                 <span class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-blue-500/20 text-blue-300 border border-blue-500/30">CONVÊNIO</span>
                              <% end %>
                           </div>
                           <p class="text-xs text-white/50 line-clamp-1">
                              <%= Enum.map(ticket.services, & &1.name) |> Enum.join(", ") %>
                           </p>
                        </div>
                     <% end %>
                  <% end %>
               </div>
            </div>
         </div>

         <%!-- Right Column: Details --%>
         <div class="col-span-8 flex flex-col h-full bg-white/5 border border-white/10 rounded-2xl backdrop-blur-md p-6 relative transition-all duration-500">
             <%= unless @selected_desk_id do %>
               <div class="absolute inset-0 z-20 bg-black/60 backdrop-blur-sm rounded-2xl flex flex-col items-center justify-center text-center p-6 grayscale">
                  <%!-- Overlay matches left side --%>
               </div>
             <% end %>

             <%= if @selected_ticket do %>
                <%!-- Active Ticket View --%>
                <div class="flex justify-between items-start mb-6">
                   <div>
                      <h2 class="text-5xl font-bold text-white mb-2 tracking-tight"><%= @selected_ticket.display_code %></h2>
                      <div class="flex gap-2">
                         <%= if @selected_ticket.is_priority do %>
                            <span class="tag bg-amber-500 text-black font-bold px-2 py-1 rounded text-sm">🚨 PRIORITÁRIO</span>
                         <% end %>
                         <%= if @selected_ticket.health_insurance_name do %>
                            <span class="tag bg-blue-500 text-white font-bold px-2 py-1 rounded text-sm">💳 CONVÊNIO</span>
                         <% end %>
                      </div>
                   </div>
                   <div class="text-right">
                      <div class="text-2xl font-bold text-yellow-400"><%= @selected_ticket.status %></div>
                      <div class="text-white/40 text-sm mt-1">🕒 Chegada: <%= Calendar.strftime(@selected_ticket.created_at, "%H:%M") %></div>
                   </div>
                </div>

                <%!-- Actions --%>
                <div class="grid grid-cols-1 gap-4 mb-8">
                   <%= cond do %>
                     <% @selected_ticket.status == "WAITING_RECEPTION" -> %>
                       <button class="w-full py-4 bg-blue-600 hover:bg-blue-500 text-white font-bold text-xl rounded-xl shadow-lg shadow-blue-900/30 transition-all active:scale-[0.98] border border-white/20" phx-click="call_ticket" phx-value-id={@selected_ticket.id}>
                          📢 CHAMAR PARA RECEPÇÃO
                       </button>

                     <% @selected_ticket.status == "CALLED_RECEPTION" -> %>
                       <button class="w-full py-4 bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xl rounded-xl shadow-lg shadow-emerald-900/30 transition-all active:scale-[0.98] border border-white/20" phx-click="start_attendance" phx-value-id={@selected_ticket.id}>
                          🟢 INICIAR ATENDIMENTO
                       </button>

                     <% @selected_ticket.status == "IN_RECEPTION" -> %>
                       <button class="w-full py-4 bg-orange-600 hover:bg-orange-500 text-white font-bold text-xl rounded-xl shadow-lg shadow-orange-900/30 transition-all active:scale-[0.98] border border-white/20" phx-click="finish_ticket" phx-value-id={@selected_ticket.id}>
                          ✓ FINALIZAR E LIBERAR
                       </button>

                     <% true -> %>
                       <div class="p-4 bg-white/10 rounded-xl text-center">Atendimento Finalizado</div>
                   <% end %>
                </div>

                <%!-- Customer Identification --%>
                <div class="bg-white/5 border border-white/10 rounded-xl p-6 mb-6">
                   <h3 class="text-white mb-4 flex items-center gap-2 font-medium">
                      <span>👤 Identificação do Cliente</span>
                   </h3>
                   <div class="flex gap-4">
                      <input type="text" placeholder="Digite o nome do cliente..." value={@selected_ticket.customer_name} class="flex-1 bg-black/20 border border-white/20 rounded-lg px-4 py-3 text-white placeholder-white/30 focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all" />
                      <button class="px-6 bg-white/10 hover:bg-white/20 text-white rounded-lg border border-white/20 transition-all">Salvar</button>
                   </div>
                </div>

                <%!-- Web Checkin Preview --%>
                <div class="bg-gradient-to-br from-emerald-900/40 to-blue-900/40 border border-emerald-500/30 rounded-xl p-6">
                   <div class="flex justify-between items-center mb-4">
                      <h3 class="text-emerald-400 font-bold flex items-center gap-2">
                         📋 Web Check-in
                         <span class="text-xs bg-emerald-500/20 text-emerald-300 px-2 py-0.5 rounded border border-emerald-500/30">
                            <%= @selected_ticket.webcheckin_status || "Não iniciado" %>
                         </span>
                      </h3>
                      <button class="text-xs bg-white/10 hover:bg-white/20 text-white px-3 py-1.5 rounded transition-all" phx-click="open_review" phx-value-id={@selected_ticket.id}>Ver Detalhes</button>
                   </div>
                   <p class="text-white/60 text-sm">O cliente iniciou o processo de check-in online. Clique para revisar os documentos e dados.</p>
                </div>

             <% else %>
                <div class="h-full flex flex-col items-center justify-center text-white/30 select-none">
                   <div class="text-6xl mb-4 opacity-50">👈</div>
                   <p class="text-xl">Selecione uma senha na lista ao lado</p>
                   <p class="text-sm opacity-50 mt-2">Os detalhes do atendimento aparecerão aqui</p>
                </div>
             <% end %>
         </div>
      </div>
    </div>
    """
  end
end
