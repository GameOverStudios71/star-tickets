defmodule StarTicketsWeb.ProfessionalLive do
  use StarTicketsWeb, :live_view

  alias StarTicketsWeb.ImpersonationHelpers
  alias StarTickets.Accounts
  alias StarTickets.Tickets
  alias StarTickets.Repo

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    socket =
      socket
      |> assign(impersonation_assigns)
      |> assign(:selected_room_id, nil)
      |> assign(:selected_room, nil)
      |> assign(:selected_ticket, nil)
      |> assign(:selected_ticket, nil)
      |> assign(:tab, "active")
      |> assign(:tickets, [])
      |> load_rooms()

    if connected?(socket) do
      user = socket.assigns.current_scope.user

      StarTicketsWeb.Presence.track(
        self(),
        "system:presence",
        "user:professional:#{user.id}",
        presence_metadata(
          user,
          socket.assigns.selected_establishment_id,
          socket.assigns.selected_room_id
        )
      )

      Tickets.subscribe()
      # Clean up any stale occupations by this user
      Accounts.vacate_rooms_by_user(socket.assigns.current_scope.user.id)
    end

    {:ok, socket}
  end

  def terminate(_reason, socket) do
    # Vacate room on exit
    if socket.assigns.current_scope.user do
      Accounts.vacate_rooms_by_user(socket.assigns.current_scope.user.id)
    end
  end

  def handle_event("select_room", %{"id" => ""}, socket) do
    if socket.assigns.selected_room do
      Accounts.vacate_room(socket.assigns.selected_room)
    end

    user = socket.assigns.current_scope.user

    StarTicketsWeb.Presence.update(
      self(),
      "system:presence",
      "user:professional:#{user.id}",
      presence_metadata(user, socket.assigns.selected_establishment_id, nil)
    )

    {:noreply,
     socket
     |> assign(:selected_room, nil)
     |> assign(:tickets, [])
     |> push_event("save_room_preference", %{id: nil})}
  end

  def handle_event("select_room", %{"id" => id}, socket) do
    room_id = String.to_integer(id)

    # 1. Vacate current room if any
    if socket.assigns.selected_room do
      Accounts.vacate_room(socket.assigns.selected_room)
    end

    # 2. Occupy new room
    room = Enum.find(socket.assigns.rooms, &(&1.id == room_id))

    if room &&
         (!room.occupied_by_user_id ||
            room.occupied_by_user_id == socket.assigns.current_scope.user.id) do
      {:ok, _updated_room} = Accounts.occupy_room(room, socket.assigns.current_scope.user.id)

      # Refresh rooms list to reflect occupation
      socket = load_rooms(socket)
      # Reload with new state (re-find room from fresh list)
      room = Enum.find(socket.assigns.rooms, &(&1.id == room_id))

      socket =
        socket
        |> assign(:selected_room_id, room_id)
        |> assign(:selected_room, room)
        |> load_tickets()
        |> push_event("save_room_preference", %{id: room_id})

      user = socket.assigns.current_scope.user

      StarTicketsWeb.Presence.update(
        self(),
        "system:presence",
        "user:professional:#{user.id}",
        presence_metadata(user, socket.assigns.selected_establishment_id, room_id)
      )

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Sala indisponível ou ocupada!")}
    end
  end

  def handle_event("restore_room_preference", %{"id" => id}, socket) do
    id_int = String.to_integer(id)
    # Refresh rooms to get latest state
    socket = load_rooms(socket)
    room = Enum.find(socket.assigns.rooms, &(&1.id == id_int))

    socket =
      if room &&
           (!room.occupied_by_user_id ||
              room.occupied_by_user_id == socket.assigns.current_scope.user.id) do
        # Occupy it
        Accounts.occupy_room(room, socket.assigns.current_scope.user.id)

        # Reload room with new state
        room = %{room | occupied_by_user_id: socket.assigns.current_scope.user.id}

        socket
        |> assign(:selected_room_id, id_int)
        |> assign(:selected_room, room)
        |> load_tickets()

        user = socket.assigns.current_scope.user

        StarTicketsWeb.Presence.update(
          self(),
          "system:presence",
          "user:professional:#{user.id}",
          presence_metadata(user, socket.assigns.selected_establishment_id, id_int)
        )

        socket
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("select_ticket", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id)
    {:noreply, assign(socket, :selected_ticket, ticket)}
  end

  def handle_event("call_ticket", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id)
    user_id = socket.assigns.current_scope.user.id
    room_id = socket.assigns.selected_room_id

    case Tickets.call_ticket_to_room(ticket, user_id, room_id, socket.assigns.current_scope.user) do
      {:ok, _ticket} ->
        {:noreply,
         socket
         |> put_flash(:info, "Paciente chamado!")
         |> load_tickets()
         # Clear selection to force refresh or re-select
         |> assign(:selected_ticket, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao chamar paciente.")}
    end
  end

  def handle_event("start_attendance", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id)
    {:ok, _} = Tickets.start_professional_attendance(ticket, socket.assigns.current_scope.user)
    {:noreply, socket |> put_flash(:info, "Atendimento iniciado!") |> load_tickets()}
  end

  def handle_event("finish_attendance", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id) |> Repo.preload(:services)

    room_services =
      if socket.assigns.selected_room.all_services do
        ticket.services
      else
        socket.assigns.selected_room.services
      end

    {:ok, updated_ticket} =
      Tickets.finish_attendance_and_route(
        ticket,
        room_services,
        socket.assigns.current_scope.user
      )

    msg =
      if updated_ticket.status == "FINISHED" do
        "Atendimento finalizado com sucesso."
      else
        "Serviços realizados. Paciente encaminhado para próxima etapa."
      end

    {:noreply,
     socket
     |> put_flash(:info, msg)
     |> load_tickets()
     |> assign(:selected_ticket, nil)}
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:tab, tab)
     |> load_tickets()}
  end

  # PubSub handling
  def handle_info({:ticket_created, _}, socket), do: {:noreply, load_tickets(socket)}
  def handle_info({:ticket_updated, _}, socket), do: {:noreply, load_tickets(socket)}
  def handle_info({:ticket_called, _}, socket), do: {:noreply, load_tickets(socket)}

  defp load_rooms(socket) do
    if socket.assigns.selected_establishment_id do
      # Need to preload services to know capabilities AND occupied_by_user
      # list_rooms already preloads both now
      rooms = Accounts.list_rooms(socket.assigns.selected_establishment_id)

      # Filter only professional rooms (type = "professional" or "both")
      # Reception desks (type = "reception") should not appear here
      professional_rooms =
        Enum.filter(rooms, fn room ->
          room.type in ["professional"]
        end)

      assign(socket, :rooms, professional_rooms)
    else
      assign(socket, :rooms, [])
    end
  end

  defp load_tickets(socket) do
    if socket.assigns.selected_room do
      if socket.assigns.tab == "finished" do
        tickets =
          Tickets.list_finished_professional_tickets(
            socket.assigns.selected_establishment_id,
            socket.assigns.current_scope.user.id
          )

        socket
        |> assign(:tickets, tickets)
        |> assign(:active_ticket, nil)
      else
        # If room is configured for all services, fetch all services from establishment
        services_to_filter =
          if socket.assigns.selected_room.all_services do
            Accounts.list_establishment_services(socket.assigns.selected_establishment_id)
          else
            socket.assigns.selected_room.services
          end

        tickets =
          Tickets.list_professional_tickets(
            socket.assigns.selected_establishment_id,
            services_to_filter
          )

        # Also find if I'm currently attending someone (IN_ATTENDANCE or CALLED_PROFESSIONAL assigned to me)
        my_user_id = socket.assigns.current_scope.user.id

        # Let's add active_ticket to assigns
        active_ticket =
          Tickets.list_reception_tickets(socket.assigns.selected_establishment_id)
          |> Enum.find(fn t ->
            t.user_id == my_user_id and t.status in ["CALLED_PROFESSIONAL", "IN_ATTENDANCE"]
          end)

        socket
        |> assign(:tickets, tickets)
        |> assign(:active_ticket, active_ticket)
        |> assign(:selected_ticket, active_ticket || socket.assigns.selected_ticket)
      end
    else
      socket
      |> assign(:tickets, [])
      |> assign(:active_ticket, nil)
    end
  end

  defp presence_metadata(user, establishment_id, room_id) do
    %{
      type: "professional",
      id: user.id,
      name: user.name,
      email: user.email,
      online_at: System.system_time(:second),
      establishment_id: establishment_id,
      room_id: room_id
    }
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col">
      <.app_header
        title="Área do Profissional"
        show_home={true}
        current_scope={@current_scope}
        {assigns}
      >
        <:right>
          <div class="flex items-center gap-3" phx-hook="RoomPreference" id="room-preference">
            <span class="text-white font-medium">
              {if @selected_room, do: "✅ Sala Ativa:", else: "🏥 Selecione sua Sala:"}
            </span>
            <form phx-change="select_room" class="m-0">
              <select
                name="id"
                class="bg-black/30 text-white border border-white/20 rounded-lg px-3 py-1.5 focus:ring-2 focus:ring-emerald-500 outline-none backdrop-blur-md"
              >
                <option value="" selected={is_nil(@selected_room_id)}>Escolher...</option>
                <%= for room <- @rooms do %>
                  <% is_occupied =
                    room.occupied_by_user_id && room.occupied_by_user_id != @current_scope.user.id

                  occupier_name =
                    if is_occupied && room.occupied_by_user,
                      do: " (#{room.occupied_by_user.name})",
                      else: "" %>
                  <option
                    value={room.id}
                    selected={@selected_room_id == room.id}
                    disabled={is_occupied}
                    class={if is_occupied, do: "text-red-400 bg-black/80", else: "text-white"}
                  >
                    {room.name}{occupier_name}
                  </option>
                <% end %>
              </select>
            </form>
          </div>
        </:right>
      </.app_header>

      <div class="st-container flex-1 p-6">
        <%= unless @selected_room_id do %>
          <div class="h-full flex flex-col items-center justify-center text-white/50 bg-emerald-950/30 backdrop-blur-md rounded-2xl border border-emerald-500/10">
            <div class="text-6xl mb-4">🏥</div>
            <h2 class="text-2xl font-bold text-white mb-2">Selecione sua Sala</h2>
            <p>Escolha a sala onde você está atendendo no menu superior.</p>
          </div>
        <% else %>
          <div class="grid grid-cols-12 gap-6 h-[calc(100vh-140px)]">
            <%!-- Left: Queue --%>
            <div class="col-span-4 flex flex-col gap-4 h-full bg-emerald-950/30 backdrop-blur-md rounded-2xl p-4 border border-emerald-500/10 shadow-xl">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2 w-full">
                  <button
                    phx-click="set_tab"
                    phx-value-tab="active"
                    class={"flex-1 py-1.5 px-3 rounded-md text-sm font-bold transition-all " <>
                                if(@tab == "active",
                                   do: "bg-emerald-600 text-white shadow-lg",
                                   else: "text-white/50 hover:text-white hover:bg-white/5")}
                  >
                    👥 Aguardando
                    <span class="ml-1 opacity-75 text-xs bg-black/20 px-1.5 rounded-full">
                      {length(@tickets)}
                    </span>
                  </button>
                  <button
                    phx-click="set_tab"
                    phx-value-tab="finished"
                    class={"flex-1 py-1.5 px-3 rounded-md text-sm font-bold transition-all " <>
                                if(@tab == "finished",
                                   do: "bg-emerald-600 text-white shadow-lg",
                                   else: "text-white/50 hover:text-white hover:bg-white/5")}
                  >
                    ✅ Finalizados
                  </button>
                </div>
              </div>

              <div class="flex-1 overflow-y-auto custom-scrollbar space-y-3 pr-2">
                <%= for ticket <- @tickets do %>
                  <div
                    phx-click="select_ticket"
                    phx-value-id={ticket.id}
                    class={"p-4 rounded-xl border transition-all cursor-pointer relative overflow-hidden group " <>
                             if(@selected_ticket && @selected_ticket.id == ticket.id,
                                do: "bg-white/10 border-emerald-500/50 shadow-[0_0_15px_rgba(16,185,129,0.2)]",
                                else: "bg-white/5 border-white/5 hover:bg-white/10 hover:border-white/20")}
                  >
                    <div class="flex justify-between items-start mb-2">
                      <span class="text-2xl font-bold text-white font-mono tracking-tighter">
                        {ticket.display_code}
                      </span>
                      <%= if ticket.is_priority do %>
                        <span class="bg-amber-500 text-black text-[10px] font-bold px-1.5 py-0.5 rounded uppercase">
                          Prioridade
                        </span>
                      <% end %>
                    </div>
                    <div class="text-white/80 font-medium truncate mb-1">
                      {ticket.customer_name || "Sem identificação"}
                    </div>
                    <div class="text-white/40 text-xs flex items-center gap-2 flex-wrap">
                      <span>🕒 {Calendar.strftime(ticket.inserted_at, "%H:%M")}</span>
                      <%= case ticket.status do %>
                        <% "WAITING_PROFESSIONAL" -> %>
                          <span class="bg-emerald-500/20 text-emerald-300 px-1.5 py-0.5 rounded text-[10px] border border-emerald-500/30 font-bold">
                            🆕 Aguardando
                          </span>
                        <% "WAITING_NEXT_SERVICE" -> %>
                          <span class="bg-blue-500/20 text-blue-300 px-1.5 py-0.5 rounded text-[10px] border border-blue-500/30 font-bold">
                            🔄 Retorno
                          </span>
                        <% "FINISHED" -> %>
                          <span class="bg-gray-500/20 text-gray-300 px-1.5 py-0.5 rounded text-[10px] border border-gray-500/30 font-bold">
                            ✅ Finalizado
                          </span>
                        <% other -> %>
                          <span class="bg-white/10 text-white/50 px-1.5 py-0.5 rounded text-[10px] border border-white/10">
                            {other}
                          </span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                <%= if Enum.empty?(@tickets) do %>
                  <div class="text-center py-10 text-white/30 border-2 border-dashed border-white/5 rounded-xl">
                    Nenhum paciente aguardando para esta sala.
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Right: Active Ticket / Details --%>
            <div class="col-span-8 flex flex-col h-full">
              <%= if @active_ticket do %>
                <%!-- Active Patient Card --%>
                <div class="bg-gradient-to-br from-emerald-900/80 to-black/90 border border-emerald-500/40 rounded-2xl p-8 shadow-2xl backdrop-blur-xl relative overflow-hidden flex-1 flex flex-col">
                  <div class="absolute top-0 right-0 p-4">
                    <span class="bg-emerald-500 text-white font-bold px-3 py-1 rounded-full text-sm shadow-lg animate-pulse">
                      {if @active_ticket.status == "CALLED_PROFESSIONAL",
                        do: "📢 CHAMANDO...",
                        else: "👨‍⚕️ EM ATENDIMENTO"}
                    </span>
                  </div>

                  <div class="grid grid-cols-1 gap-4 mb-8 mt-12">
                    <%= if @active_ticket.status == "CALLED_PROFESSIONAL" do %>
                      <button
                        id={"prof-start-#{@active_ticket.id}"}
                        phx-hook="DebounceSubmit"
                        phx-click="start_attendance"
                        phx-value-id={@active_ticket.id}
                        class="w-full py-5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-2xl rounded-xl shadow-lg transition-transform hover:scale-[1.01] active:scale-[0.99] border border-white/20"
                      >
                        ▶️ INICIAR CONSULTA
                      </button>
                    <% else %>
                      <button
                        id={"prof-finish-#{@active_ticket.id}"}
                        phx-hook="DebounceSubmit"
                        phx-click="finish_attendance"
                        phx-value-id={@active_ticket.id}
                        class="w-full py-5 bg-orange-600 hover:bg-orange-500 text-white font-bold text-2xl rounded-xl shadow-lg transition-transform hover:scale-[1.01] active:scale-[0.99] border border-white/20"
                      >
                        ✅ FINALIZAR
                      </button>
                    <% end %>
                  </div>

                  <div class="mb-8">
                    <h1 class="text-6xl font-black text-white mb-2 font-mono tracking-tighter">
                      {@active_ticket.display_code}
                    </h1>
                    <h2 class="text-3xl text-emerald-100 font-bold">
                      {@active_ticket.customer_name}
                    </h2>
                    <%= if @active_ticket.is_priority do %>
                      <span class="text-amber-400 font-bold text-lg mt-2 block">★ PRIORIDADE</span>
                    <% end %>
                  </div>

                  <div class="grid grid-cols-2 gap-6 bg-black/20 p-6 rounded-xl border border-white/5">
                    <div>
                      <span class="text-white/40 text-sm block mb-1">
                        Serviços Pendentes Nesta Sala:
                      </span>
                      <div class="flex flex-wrap gap-2">
                        <%= for service <- @active_ticket.services do %>
                          <%= if Enum.any?(@selected_room.services, &(&1.id == service.id)) do %>
                            <span class="bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 px-2 py-1 rounded text-sm">
                              {service.name}
                            </span>
                          <% end %>
                        <% end %>
                      </div>
                    </div>
                    <div>
                      <span class="text-white/40 text-sm block mb-1">Outros Serviços:</span>
                      <div class="flex flex-wrap gap-2">
                        <%= for service <- @active_ticket.services do %>
                          <%= unless Enum.any?(@selected_room.services, &(&1.id == service.id)) do %>
                            <span class="bg-white/10 text-white/60 border border-white/10 px-2 py-1 rounded text-sm">
                              {service.name}
                            </span>
                          <% end %>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              <% else %>
                <%!-- Selection State --%>
                <%= if @selected_ticket do %>
                  <div class="bg-emerald-950/50 backdrop-blur-xl p-8 rounded-2xl border border-emerald-500/10 h-full flex flex-col shadow-2xl">
                    <div class="mb-6">
                      <%= if @tab != "finished" do %>
                        <button
                          id={"prof-call-#{@selected_ticket.id}"}
                          phx-hook="DebounceSubmit"
                          phx-click="call_ticket"
                          phx-value-id={@selected_ticket.id}
                          class="w-full py-4 bg-blue-600 hover:bg-blue-500 text-white font-bold text-xl rounded-xl transition-all border border-white/20 shadow-lg shadow-blue-500/20"
                        >
                          📢 CHAMAR PACIENTE
                        </button>
                      <% else %>
                        <div class="w-full py-4 bg-emerald-500/10 border border-emerald-500/20 rounded-xl text-center">
                          <span class="text-emerald-400 font-bold text-lg">
                            ✅ Atendimento Finalizado
                          </span>
                          <div class="text-white/40 text-sm mt-1">
                            Concluído em {Calendar.strftime(@selected_ticket.updated_at, "%H:%M")}
                          </div>
                        </div>
                      <% end %>
                    </div>

                    <h2 class="text-3xl font-bold text-white mb-6">Detalhes da Senha</h2>

                    <div class="flex-1">
                      <div class="p-6 bg-black/20 rounded-xl mb-6">
                        <div class="text-4xl font-mono font-bold text-white mb-2">
                          {@selected_ticket.display_code}
                        </div>
                        <div class="text-xl text-white/80">
                          {@selected_ticket.customer_name || "Sem nome"}
                        </div>
                      </div>
                      <h3 class="text-white/60 uppercase text-sm font-bold mb-3">
                        Serviços Solicitados
                      </h3>
                      <div class="flex flex-col gap-2">
                        <%= for service <- @selected_ticket.services do %>
                          <div class={"p-3 rounded-lg border flex justify-between items-center " <>
                                     if(Enum.any?(@selected_room.services, &(&1.id == service.id)),
                                        do: "bg-emerald-500/10 border-emerald-500/30 text-emerald-100",
                                        else: "bg-white/5 border-white/10 text-white/50")}>
                            <span>{service.name}</span>
                            <%= if Enum.any?(@selected_room.services, &(&1.id == service.id)) do %>
                              <span class="text-xs bg-emerald-500/20 px-2 py-0.5 rounded">
                                Sua Sala
                              </span>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <div class="bg-emerald-950/30 backdrop-blur-md border border-emerald-500/10 rounded-2xl h-full flex flex-col items-center justify-center text-center text-white/40 shadow-xl">
                    <div class="text-4xl mb-4">👈</div>
                    <p class="text-lg">
                      Selecione um paciente na lista<br />para visualizar os detalhes.
                    </p>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
