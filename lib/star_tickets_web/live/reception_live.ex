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
      # Tag filters state (names, not IDs, for grouping)
      |> assign(:taggable_menus, [])
      |> assign(:selected_tag_names, [])
      # Service filters (checkbox, list of service IDs)
      |> assign(:selected_service_ids, [])
      # Date filter: "today", "12h", "24h", "48h", "all"
      |> assign(:date_filter, "today")
      # Service management state (during IN_RECEPTION)
      |> assign(:editing_services, [])
      |> assign(:available_services, [])
      |> assign(:customer_name_input, "")
      # Track the ticket currently being attended by this receptionist
      |> assign(:attending_ticket_id, nil)
      # Collapsible sections state
      |> assign(:section_states, %{date: true, tags: false, services: false})
      |> load_taggable_menus()
      |> load_available_services()
      |> load_desks()
      |> load_tickets()
      |> restore_attending_ticket()

    if connected?(socket) do
      Tickets.subscribe()
      Reception.subscribe()
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:ticket_created, ticket}, socket) do
    # Only append if relevant to current filter? For now reload or append.
    # Simple strategy: prepend to all_tickets and re-filter

    # Needs preloads (services, desk) for proper display
    ticket = Repo.preload(ticket, [:services, :reception_desk, :tags])

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
    ticket = Repo.preload(ticket, [:services, :reception_desk, :tags])

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

  defp load_taggable_menus(socket) do
    if socket.assigns.selected_establishment_id do
      menus = Accounts.list_taggable_menus(socket.assigns.selected_establishment_id)
      assign(socket, :taggable_menus, menus)
    else
      assign(socket, :taggable_menus, [])
    end
  end

  defp load_available_services(socket) do
    if socket.assigns.selected_establishment_id do
      services = Accounts.list_establishment_services(socket.assigns.selected_establishment_id)
      assign(socket, :available_services, services)
    else
      assign(socket, :available_services, [])
    end
  end

  defp load_tickets(socket) do
    if socket.assigns.selected_establishment_id do
      all_tickets = Tickets.list_reception_tickets(socket.assigns.selected_establishment_id)

      # Filter and assign
      filtered_tickets =
        filter_tickets(
          all_tickets,
          socket.assigns.active_tab,
          socket.assigns.selected_tag_names,
          socket.assigns.taggable_menus,
          socket.assigns.selected_service_ids,
          socket.assigns.date_filter
        )

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

  # Restore attending ticket state on page reload
  defp restore_attending_ticket(socket) do
    # Find any ticket that is IN_RECEPTION in the current establishment
    in_reception_ticket =
      socket.assigns.all_tickets
      |> Enum.find(&(&1.status == "IN_RECEPTION"))

    if in_reception_ticket do
      socket
      |> assign(:attending_ticket_id, in_reception_ticket.id)
      |> assign(:selected_ticket, in_reception_ticket)
      |> assign(:editing_services, in_reception_ticket.services)
      |> assign(:customer_name_input, in_reception_ticket.customer_name || "")
    else
      socket
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

  defp filter_tickets(
         tickets,
         tab,
         selected_tag_names,
         taggable_menus,
         selected_service_ids,
         date_filter
       ) do
    # 1. Filter by Date
    filtered =
      case date_filter do
        "12h" ->
          cutoff = DateTime.utc_now() |> DateTime.add(-12, :hour)
          Enum.filter(tickets, &(DateTime.compare(&1.inserted_at, cutoff) == :gt))

        "24h" ->
          cutoff = DateTime.utc_now() |> DateTime.add(-24, :hour)
          Enum.filter(tickets, &(DateTime.compare(&1.inserted_at, cutoff) == :gt))

        "48h" ->
          cutoff = DateTime.utc_now() |> DateTime.add(-48, :hour)
          Enum.filter(tickets, &(DateTime.compare(&1.inserted_at, cutoff) == :gt))

        "today" ->
          today = Date.utc_today()
          Enum.filter(tickets, &(Date.compare(DateTime.to_date(&1.inserted_at), today) == :eq))

        _ ->
          tickets
      end

    # 2. Filter by Tab
    filtered =
      case tab do
        "active" ->
          Enum.filter(
            filtered,
            &(&1.status in ["pending", "WAITING_RECEPTION", "CALLED_RECEPTION", "IN_RECEPTION"])
          )

        "finished" ->
          Enum.filter(
            filtered,
            &(&1.status not in [
                "pending",
                "WAITING_RECEPTION",
                "CALLED_RECEPTION",
                "IN_RECEPTION"
              ])
          )

        _ ->
          filtered
      end

    # 3. Filter by Tags (if any selected)
    filtered =
      if Enum.empty?(selected_tag_names) do
        filtered
      else
        # Get all IDs for selected tag names (grouped)
        selected_ids =
          taggable_menus
          |> Enum.filter(&(&1.name in selected_tag_names))
          |> Enum.flat_map(& &1.ids)

        Enum.filter(filtered, fn ticket ->
          ticket_tag_ids = Enum.map(ticket.tags, & &1.id)
          # Show if ticket has ANY of the selected tag IDs
          Enum.any?(selected_ids, &(&1 in ticket_tag_ids))
        end)
      end

    # 4. Filter by Services (if any selected)
    filtered =
      if Enum.empty?(selected_service_ids) do
        filtered
      else
        Enum.filter(filtered, fn ticket ->
          ticket_service_ids = Enum.map(ticket.services, & &1.id)
          # Show if ticket has ANY of the selected services
          Enum.any?(selected_service_ids, &(&1 in ticket_service_ids))
        end)
      end

    # 5. Sort: Priority tickets first, then by inserted_at
    Enum.sort_by(filtered, fn ticket ->
      is_preferencial = Enum.any?(ticket.tags, &String.contains?(&1.name, "Preferencial"))
      priority_score = if ticket.is_priority || is_preferencial, do: 0, else: 1
      {priority_score, ticket.inserted_at}
    end)
  end

  def handle_info({:desk_updated, _desk}, socket) do
    {:noreply, load_desks(socket)}
  end

  def handle_info({:desk_created, _desk}, socket) do
    {:noreply, load_desks(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("select_desk", %{"desk_id" => desk_id}, socket) do
    id = if desk_id == "", do: nil, else: String.to_integer(desk_id)

    if id do
      case Reception.get_desk!(id) do
        desk ->
          # Check if occupied by someone else (safety check)
          if desk.occupied_by_user_id &&
               desk.occupied_by_user_id != socket.assigns.current_user.id do
            {:noreply, put_flash(socket, :error, "Esta mesa já está ocupada.")}
          else
            {:ok, _desk} = Reception.occupy_desk(desk, socket.assigns.current_user.id)

            socket =
              socket
              |> assign(:selected_desk_id, id)
              |> push_event("save_desk_preference", %{id: id})

            {:noreply, socket}
          end
      end
    else
      # Deselecting?
      if socket.assigns.selected_desk_id do
        old_desk = Reception.get_desk!(socket.assigns.selected_desk_id)

        if old_desk.occupied_by_user_id == socket.assigns.current_user.id do
          Reception.release_desk(old_desk)
        end
      end

      socket =
        socket
        |> assign(:selected_desk_id, nil)
        |> push_event("save_desk_preference", %{id: nil})

      {:noreply, socket}
    end
  end

  def handle_event("restore_desk_preference", %{"id" => id}, socket) do
    id = String.to_integer(id)

    # Verify if desk exists in current list (security check)
    # Find the desk object
    desk = Enum.find(socket.assigns.desks, &(&1.id == id))

    socket =
      if desk do
        cond do
          # Occupied by me -> Just select it
          desk.occupied_by_user_id == socket.assigns.current_user.id ->
            assign(socket, :selected_desk_id, id)

          # Free -> Occupy it and select it
          is_nil(desk.occupied_by_user_id) ->
            {:ok, _desk} = Reception.occupy_desk(desk, socket.assigns.current_user.id)
            assign(socket, :selected_desk_id, id)

          # Occupied by someone else -> Ignore preference
          true ->
            socket
        end
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

  def handle_event("toggle_service_filter", %{"id" => id}, socket) do
    service_id = String.to_integer(id)
    current = socket.assigns.selected_service_ids

    new_selected =
      if service_id in current do
        List.delete(current, service_id)
      else
        [service_id | current]
      end

    socket =
      socket
      |> assign(:selected_service_ids, new_selected)
      |> refresh_tickets_view()

    {:noreply, socket}
  end

  def handle_event("set_date_filter", %{"filter_date" => value}, socket) do
    # Ensure value is clean
    clean_value = String.trim(value)

    socket =
      socket
      |> assign(:date_filter, clean_value)
      |> refresh_tickets_view()

    {:noreply, socket}
  end

  def handle_event("change_ticket_status", %{"id" => id, "status" => new_status}, socket) do
    ticket = Tickets.get_ticket!(id)
    {:ok, _updated} = Tickets.update_ticket_status(ticket, new_status)

    # Refresh the list
    socket = load_tickets(socket)

    {:noreply, socket}
  end

  def handle_event("toggle_section", %{"section" => section}, socket) do
    key = String.to_atom(section)
    current_state = socket.assigns.section_states[key]
    new_states = Map.put(socket.assigns.section_states, key, !current_state)
    {:noreply, assign(socket, :section_states, new_states)}
  end

  def handle_event("select_ticket", %{"id" => id}, socket) do
    ticket = Enum.find(socket.assigns.all_tickets, &(&1.id == String.to_integer(id)))
    # Start WebCheckin review if needed?
    {:noreply, assign(socket, :selected_ticket, ticket)}
  end

  def handle_event("call_ticket", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id)

    # Set status AND assign to current user to lock it
    attrs = %{
      status: "CALLED_RECEPTION",
      user_id: socket.assigns.current_user.id
    }

    case Tickets.update_ticket(ticket, attrs) do
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
    # Check if receptionist already has an open ticket
    current_attending = socket.assigns[:attending_ticket_id]

    if current_attending && current_attending != String.to_integer(id) do
      # Block: already has an open ticket
      socket =
        socket
        |> put_flash(
          :error,
          "⚠️ Você já tem um atendimento em andamento. Finalize o ticket atual antes de iniciar outro."
        )

      {:noreply, socket}
    else
      ticket = Tickets.get_ticket!(id)
      # Use start_attendance to assign current user
      {:ok, updated_ticket} = Tickets.start_attendance(ticket, socket.assigns.current_user.id)

      # Populate editing state and track attending ticket
      socket =
        socket
        |> assign(:attending_ticket_id, updated_ticket.id)
        |> assign(:selected_ticket, updated_ticket)
        |> assign(:editing_services, updated_ticket.services)
        |> assign(:customer_name_input, updated_ticket.customer_name || "")
        |> load_tickets()

      {:noreply, socket}
    end
  end

  def handle_event("update_customer_name", %{"customer_name" => value}, socket) do
    {:noreply, assign(socket, :customer_name_input, value)}
  end

  def handle_event("update_customer_name", %{"value" => value}, socket) do
    {:noreply, assign(socket, :customer_name_input, value)}
  end

  def handle_event("save_customer_name", %{"customer_name" => value}, socket) do
    save_customer_name_to_ticket(socket, value)
  end

  def handle_event("save_customer_name", %{"value" => value}, socket) do
    save_customer_name_to_ticket(socket, value)
  end

  defp save_customer_name_to_ticket(socket, value) do
    customer_name = String.trim(value)

    if socket.assigns.selected_ticket && customer_name != "" do
      ticket = socket.assigns.selected_ticket

      # Update just the customer name
      Tickets.update_ticket(ticket, %{customer_name: customer_name})

      socket =
        socket
        |> assign(:customer_name_input, customer_name)
        |> load_tickets()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("move_service_up", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    services = socket.assigns.editing_services

    if index > 0 do
      new_services = swap_at(services, index, index - 1)
      {:noreply, assign(socket, :editing_services, new_services)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("move_service_down", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    services = socket.assigns.editing_services

    if index < length(services) - 1 do
      new_services = swap_at(services, index, index + 1)
      {:noreply, assign(socket, :editing_services, new_services)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("add_service", %{"service_id" => ""}, socket), do: {:noreply, socket}

  def handle_event("add_service", %{"service_id" => service_id_str}, socket) do
    service_id = String.to_integer(service_id_str)
    service = Enum.find(socket.assigns.available_services, &(&1.id == service_id))

    if service && not Enum.any?(socket.assigns.editing_services, &(&1.id == service_id)) do
      new_services = socket.assigns.editing_services ++ [service]
      {:noreply, assign(socket, :editing_services, new_services)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_service", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    new_services = List.delete_at(socket.assigns.editing_services, index)
    {:noreply, assign(socket, :editing_services, new_services)}
  end

  def handle_event("save_attendance", %{"id" => id}, socket) do
    customer_name = String.trim(socket.assigns.customer_name_input)

    if customer_name == "" do
      {:noreply, put_flash(socket, :error, "Nome do cliente é obrigatório!")}
    else
      ticket = Tickets.get_ticket!(id)

      # Update ticket with customer name and services
      {:ok, _} =
        Tickets.update_ticket_with_services(
          ticket,
          %{customer_name: customer_name},
          socket.assigns.editing_services
        )

      # Clear editing state
      socket =
        socket
        |> assign(:editing_services, [])
        |> assign(:customer_name_input, "")
        |> put_flash(:info, "Dados salvos com sucesso!")
        |> load_tickets()

      {:noreply, socket}
    end
  end

  def handle_event("finish_ticket", %{"id" => id}, socket) do
    customer_name = String.trim(socket.assigns.customer_name_input)

    if customer_name == "" do
      {:noreply, put_flash(socket, :error, "Nome do cliente é obrigatório para finalizar!")}
    else
      ticket = Tickets.get_ticket!(id)

      # Save and finish
      {:ok, _} =
        Tickets.update_ticket_with_services(
          ticket,
          %{customer_name: customer_name, status: "WAITING_PROFESSIONAL"},
          socket.assigns.editing_services
        )

      # Clear editing state
      socket =
        socket
        |> assign(:editing_services, [])
        |> assign(:customer_name_input, "")
        |> put_flash(:info, "Atendimento finalizado!")
        |> load_tickets()

      {:noreply, socket}
    end
  end

  defp swap_at(list, idx1, idx2) do
    a = Enum.at(list, idx1)
    b = Enum.at(list, idx2)

    list
    |> List.replace_at(idx1, b)
    |> List.replace_at(idx2, a)
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

  def handle_event("toggle_tag_filter", %{"name" => name}, socket) do
    current = socket.assigns.selected_tag_names

    new_selected =
      if name in current do
        List.delete(current, name)
      else
        [name | current]
      end

    socket =
      socket
      |> assign(:selected_tag_names, new_selected)
      |> refresh_tickets_view()

    {:noreply, socket}
  end

  defp refresh_tickets_view(socket) do
    filtered =
      filter_tickets(
        socket.assigns.all_tickets,
        socket.assigns.active_tab,
        socket.assigns.selected_tag_names,
        socket.assigns.taggable_menus,
        socket.assigns.selected_service_ids,
        socket.assigns.date_filter
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
         {assigns}
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
                       <%
                         is_occupied = desk.occupied_by_user_id && desk.occupied_by_user_id != @current_user.id
                         occupier_name = if is_occupied && desk.occupied_by_user, do: " (#{desk.occupied_by_user.name})", else: ""
                       %>
                       <option value={desk.id} selected={@selected_desk_id == desk.id} disabled={is_occupied} class={if is_occupied, do: "text-red-400 bg-black", else: ""}>
                         <%= desk.name %><%= occupier_name %>
                       </option>
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

            <%!-- Collapsible Filter Sections --%>
            <div class={"flex flex-col gap-2 transition-all " <> if(!@selected_desk_id, do: "opacity-30 blur-[2px] pointer-events-none", else: "")}>

               <div class="group bg-white/5 border border-white/10 rounded-xl backdrop-blur-md overflow-hidden">
                  <button type="button" phx-click="toggle_section" phx-value-section="date" class="w-full flex items-center justify-between p-3 cursor-pointer select-none hover:bg-white/5 transition-colors outline-none">
                     <span class="text-white font-medium text-sm flex items-center gap-2">📅 Período</span>
                     <span class={"text-white/40 transition-transform text-xs " <> if(@section_states.date, do: "rotate-180", else: "")}>▼</span>
                  </button>
                  <%= if @section_states.date do %>
                    <div class="p-3 pt-0 flex flex-wrap gap-2 border-t border-white/5 mt-2 pt-3">
                       <%= for {label, filter_val} <- [{"Hoje", "today"}, {"12h", "12h"}, {"24h", "24h"}, {"48h", "48h"}, {"Todos", "all"}] do %>
                          <button
                             type="button"
                             phx-click="set_date_filter"
                             phx-value-filter_date={filter_val}
                             class={"px-2 py-1.5 rounded text-xs transition-all select-none flex-1 text-center " <>
                                if(@date_filter == filter_val,
                                   do: "bg-emerald-500/30 text-emerald-200 border border-emerald-400/50",
                                   else: "bg-white/5 text-white/50 border border-white/10 hover:bg-white/10")}
                          ><%= label %></button>
                       <% end %>
                    </div>
                  <% end %>
               </div>

               <%!-- 2. TAGS FILTER --%>
               <%= if not Enum.empty?(@taggable_menus) do %>
                 <div class="group bg-white/5 border border-white/10 rounded-xl backdrop-blur-md overflow-hidden">
                    <button phx-click="toggle_section" phx-value-section="tags" class="w-full flex items-center justify-between p-3 cursor-pointer select-none hover:bg-white/5 transition-colors outline-none">
                       <span class="text-white font-medium text-sm flex items-center gap-2">
                          🏷️ Etiquetas
                          <%= if length(@selected_tag_names) > 0 do %>
                             <span class="bg-emerald-500 text-white text-[10px] px-1.5 rounded-full"><%= length(@selected_tag_names) %></span>
                          <% end %>
                       </span>
                       <span class={"text-white/40 transition-transform text-xs " <> if(@section_states.tags, do: "rotate-180", else: "")}>▼</span>
                    </button>
                    <%= if @section_states.tags do %>
                      <div class="p-3 pt-0 flex flex-wrap gap-2 border-t border-white/5 mt-2 pt-3">
                         <%= for tag <- @taggable_menus do %>
                            <button
                               phx-click="toggle_tag_filter"
                               phx-value-name={tag.name}
                               class={"px-2 py-1.5 rounded text-xs transition-all select-none " <>
                                  if(tag.name in @selected_tag_names,
                                     do: "bg-emerald-500/30 text-emerald-200 border border-emerald-400/50",
                                     else: "bg-white/5 text-white/50 border border-white/10 hover:bg-white/10")}
                            ><%= tag.name %></button>
                         <% end %>
                      </div>
                    <% end %>
                 </div>
               <% end %>

               <%!-- 3. SERVICES FILTER --%>
               <%= if not Enum.empty?(@available_services) do %>
                 <div class="group bg-white/5 border border-white/10 rounded-xl backdrop-blur-md overflow-hidden">
                    <button phx-click="toggle_section" phx-value-section="services" class="w-full flex items-center justify-between p-3 cursor-pointer select-none hover:bg-white/5 transition-colors outline-none">
                       <span class="text-white font-medium text-sm flex items-center gap-2">
                          🏥 Serviços
                          <%= if length(@selected_service_ids) > 0 do %>
                             <span class="bg-blue-500 text-white text-[10px] px-1.5 rounded-full"><%= length(@selected_service_ids) %></span>
                          <% end %>
                       </span>
                       <span class={"text-white/40 transition-transform text-xs " <> if(@section_states.services, do: "rotate-180", else: "")}>▼</span>
                    </button>
                    <%= if @section_states.services do %>
                      <div class="p-3 pt-0 flex flex-wrap gap-2 border-t border-white/5 mt-2 pt-3 max-h-40 overflow-y-auto custom-scrollbar">
                         <%= for service <- @available_services do %>
                            <button
                               phx-click="toggle_service_filter"
                               phx-value-id={service.id}
                               class={"px-2 py-1 rounded text-xs transition-all select-none text-left truncate max-w-full " <>
                                  if(service.id in @selected_service_ids,
                                     do: "bg-blue-500/30 text-blue-200 border border-blue-400/50",
                                     else: "bg-white/5 text-white/50 border border-white/10 hover:bg-white/10")}
                            ><%= service.name %></button>
                         <% end %>
                      </div>
                    <% end %>
                 </div>
               <% end %>

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
                        <%
                          # Determine ticket styling based on status and selection
                          is_selected = @selected_ticket && @selected_ticket.id == ticket.id
                          # Consider actively locked if IN_RECEPTION OR (CALLED_RECEPTION and has user assigned)
                          is_locked_status = ticket.status in ["IN_RECEPTION", "CALLED_RECEPTION"] # and ticket.user_id != nil (implied by next check)
                          is_mine = ticket.user_id == @current_user.id
                          is_locked_by_other = is_locked_status && ticket.user_id && !is_mine
                          is_active_for_me = is_locked_status && is_mine

                          base_class = "p-3 rounded-xl cursor-pointer transition-all group active:scale-[0.98] "

                          ticket_class = cond do
                            is_active_for_me ->
                              # Premium green acrylic for MY attendance (or my call)
                              base_class <> "bg-gradient-to-br from-emerald-500/30 to-emerald-700/20 border-2 border-emerald-400/60 shadow-lg shadow-emerald-500/20 backdrop-blur-md ring-2 ring-emerald-400/40"
                            is_locked_by_other ->
                              # Red acrylic for OTHER attendance (or call) - LOCKED
                              base_class <> "bg-gradient-to-br from-red-500/30 to-red-700/20 border-2 border-red-400/60 shadow-lg shadow-red-500/20 backdrop-blur-md opacity-70 grayscale-[0.3] pointer-events-none"
                            is_selected ->
                              base_class <> "bg-emerald-500/10 border border-emerald-500/50 ring-1 ring-emerald-500/30"
                            true ->
                              base_class <> "bg-white/5 border border-white/10 hover:bg-white/10"
                          end
                        %>
                        <div class={ticket_class} phx-click="select_ticket" phx-value-id={ticket.id}>
                           <div class="flex justify-between items-start mb-1">
                              <div>
                                 <span class="text-xl font-bold text-white"><%= ticket.display_code %></span>
                                 <%= if ticket.customer_name do %>
                                    <span class="text-sm text-emerald-400 ml-2">👤 <%= ticket.customer_name %></span>
                                 <% end %>
                              </div>
                              <%= if @active_tab == "finished" do %>
                                 <%!-- Dropdown to change status in finished tab --%>
                                 <form phx-change="change_ticket_status" phx-value-id={ticket.id}>
                                    <select name="status" class="text-xs bg-slate-800 border border-white/20 rounded px-2 py-1 text-white cursor-pointer focus:ring-2 focus:ring-emerald-500 outline-none">
                                       <option value="WAITING_RECEPTION" selected={ticket.status == "WAITING_RECEPTION"}>⏳ WAITING_RECEPTION</option>
                                       <option value="CALLED_RECEPTION" selected={ticket.status == "CALLED_RECEPTION"}>📢 CALLED_RECEPTION</option>
                                       <option value="IN_RECEPTION" selected={ticket.status == "IN_RECEPTION"}>🏢 IN_RECEPTION</option>
                                       <option value="WAITING_PROFESSIONAL" selected={ticket.status == "WAITING_PROFESSIONAL"}>⏱️ WAITING_PROFESSIONAL</option>
                                       <option value="IN_SERVICE" selected={ticket.status == "IN_SERVICE"}>🩺 IN_SERVICE</option>
                                       <option value="COMPLETED" selected={ticket.status == "COMPLETED"}>✅ COMPLETED</option>
                                       <option value="CANCELLED" selected={ticket.status == "CANCELLED"}>❌ CANCELLED</option>
                                    </select>
                                 </form>
                              <% else %>
                                 <span class={"text-xs font-bold px-2 py-0.5 rounded border " <>
                                    case ticket.status do
                                       "WAITING_RECEPTION" -> "bg-amber-500/20 text-amber-300 border-amber-500/30"
                                       "CALLED_RECEPTION" -> "bg-blue-500/20 text-blue-300 border-blue-500/30"
                                       "IN_RECEPTION" -> "bg-emerald-500/20 text-emerald-300 border-emerald-500/30"
                                       _ -> "bg-slate-500/20 text-slate-300 border-slate-500/30"
                                    end
                                 }><%= ticket.status %></span>
                              <% end %>
                           </div>
                           <div class="flex items-center gap-2 mb-2">
                              <%= if ticket.is_priority do %>
                                 <span class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30">PREFERENCIAL</span>
                              <% end %>
                              <%= if ticket.health_insurance_name do %>
                                 <span class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-blue-500/20 text-blue-300 border border-blue-500/30">CONVÊNIO</span>
                              <% end %>
                              <%= case ticket.webcheckin_status do %>
                                <% "IN_PROGRESS" -> %>
                                  <span class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-yellow-500/20 text-yellow-300 border border-yellow-500/30 animate-pulse">📱 CHECK-IN</span>
                                <% "COMPLETED" -> %>
                                  <span class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-green-500/20 text-green-300 border border-green-500/30">✅ CHECK-IN</span>
                                <% _ -> %>
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
                      <div class="text-white/40 text-sm mt-1">🕒 Chegada: <%= Calendar.strftime(@selected_ticket.inserted_at, "%H:%M") %></div>
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

                <%!-- Customer Identification & Services (only during IN_RECEPTION) --%>
                <%= if @selected_ticket.status == "IN_RECEPTION" do %>
                   <div class="bg-white/5 border border-white/10 rounded-xl p-6 mb-6">
                      <h3 class="text-white mb-4 flex items-center gap-2 font-medium">
                         <span>👤 Identificação do Cliente</span>
                         <span class="text-red-400 text-xs">(Obrigatório)</span>
                      </h3>
                       <form phx-submit="save_customer_name" phx-change="update_customer_name">
                          <input
                             name="customer_name"
                             id="customer-name-input"
                             phx-hook="AutoFocus"
                             type="text"
                             placeholder="Digite o nome do cliente e pressione Enter..."
                             value={@customer_name_input}
                             phx-blur="save_customer_name"
                             phx-debounce="100"
                             autocomplete="off"
                             class="w-full bg-black/20 border border-white/20 rounded-lg px-4 py-3 text-white placeholder-white/30 focus:ring-2 focus:ring-emerald-500 focus:border-transparent outline-none transition-all"
                          />
                       </form>
                   </div>

                   <%!-- Editable Services List --%>
                   <div class="bg-white/5 border border-white/10 rounded-xl p-6 mb-6">
                      <h3 class="text-white mb-4 flex items-center justify-between font-medium">
                         <span>🏥 Serviços Selecionados</span>
                         <span class="text-xs text-white/50"><%= length(@editing_services) %> serviço(s)</span>
                      </h3>

                      <%!-- Service List --%>
                      <div class="space-y-2 mb-4">
                         <%= for {service, index} <- Enum.with_index(@editing_services) do %>
                            <div class="flex items-center gap-2 bg-black/20 rounded-lg px-3 py-2 border border-white/10">
                               <span class="flex-1 text-white text-sm"><%= service.name %></span>
                               <button
                                  phx-click="move_service_up"
                                  phx-value-index={index}
                                  class={"text-white/50 hover:text-white p-1 transition-colors " <> if(index == 0, do: "opacity-30 cursor-not-allowed", else: "")}
                                  disabled={index == 0}
                               >⬆️</button>
                               <button
                                  phx-click="move_service_down"
                                  phx-value-index={index}
                                  class={"text-white/50 hover:text-white p-1 transition-colors " <> if(index == length(@editing_services) - 1, do: "opacity-30 cursor-not-allowed", else: "")}
                                  disabled={index == length(@editing_services) - 1}
                               >⬇️</button>
                               <button
                                  phx-click="remove_service"
                                  phx-value-index={index}
                                  class="text-red-400 hover:text-red-300 p-1 transition-colors"
                               >🗑️</button>
                            </div>
                         <% end %>
                         <%= if Enum.empty?(@editing_services) do %>
                            <div class="text-white/30 text-center py-4 border border-dashed border-white/10 rounded-lg">
                               Nenhum serviço selecionado
                            </div>
                         <% end %>
                      </div>

                      <%!-- Add Service Dropdown --%>
                      <form phx-change="add_service" class="flex gap-2">
                         <select name="service_id" class="flex-1 bg-black/20 border border-white/20 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-emerald-500 outline-none">
                            <option value="">+ Adicionar serviço...</option>
                            <%= for service <- @available_services do %>
                               <%= unless Enum.any?(@editing_services, &(&1.id == service.id)) do %>
                                  <option value={service.id}><%= service.name %></option>
                               <% end %>
                            <% end %>
                         </select>
                      </form>
                   </div>

                <% end %>

                <%!-- Web Checkin Preview (only show if webcheckin_status exists) --%>
                <%= if @selected_ticket.webcheckin_status do %>
                   <div class="bg-gradient-to-br from-emerald-900/40 to-blue-900/40 border border-emerald-500/30 rounded-xl p-6">
                      <div class="flex justify-between items-center mb-4">
                         <h3 class="text-emerald-400 font-bold flex items-center gap-2">
                            📋 Web Check-in
                            <span class="text-xs bg-emerald-500/20 text-emerald-300 px-2 py-0.5 rounded border border-emerald-500/30">
                               <%= @selected_ticket.webcheckin_status %>
                            </span>
                         </h3>
                         <button class="text-xs bg-white/10 hover:bg-white/20 text-white px-3 py-1.5 rounded transition-all" phx-click="open_review" phx-value-id={@selected_ticket.id}>Ver Detalhes</button>
                      </div>
                      <p class="text-white/60 text-sm">O cliente iniciou o processo de check-in online. Clique para revisar os documentos e dados.</p>
                   </div>
                <% end %>

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
