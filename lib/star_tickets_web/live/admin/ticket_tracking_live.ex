defmodule StarTicketsWeb.Admin.TicketTrackingLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.{Audit, Tickets, Repo, Accounts}
  alias StarTicketsWeb.ImpersonationHelpers
  import Ecto.Query

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    # Load users for dropdown - filter by establishment if manager has one selected
    establishment_id = impersonation_assigns[:selected_establishment_id]

    users =
      if establishment_id do
        Accounts.list_users(%{"establishment_id" => establishment_id})
      else
        Accounts.list_users()
      end

    # Load initial tickets (recent ones)
    initial_assigns = %{
      filter_code: "",
      filter_user_id: "",
      filter_status: "",
      filter_date_start: "",
      filter_date_end: "",
      selected_establishment_id: establishment_id
    }

    initial_tickets =
      search_tickets(
        %{code: "", user_id: "", status: "", date_start: "", date_end: ""},
        initial_assigns
      )

    {:ok,
     socket
     |> assign(impersonation_assigns)
     |> assign(:filter_code, "")
     |> assign(:filter_user_id, "")
     |> assign(:filter_status, "")
     |> assign(:filter_date_start, "")
     |> assign(:filter_date_end, "")
     |> assign(:all_users, users)
     |> assign(:tickets, initial_tickets)
     |> assign(:selected_ticket, nil)
     |> assign(:selected_logs, [])
     |> assign(:page_title, "Ticket Tracking")}
  end

  def handle_event("filter", params, socket) do
    filters = %{
      code: String.trim(params["code"] || ""),
      user_id: params["user_id"] || "",
      status: params["status"] || "",
      date_start: params["date_start"] || "",
      date_end: params["date_end"] || ""
    }

    tickets = search_tickets(filters, socket.assigns)

    {:noreply,
     socket
     |> assign(:filter_code, filters.code)
     |> assign(:filter_user_id, filters.user_id)
     |> assign(:filter_status, filters.status)
     |> assign(:filter_date_start, filters.date_start)
     |> assign(:filter_date_end, filters.date_end)
     |> assign(:tickets, tickets)
     |> assign(:selected_ticket, nil)
     |> assign(:selected_logs, [])}
  end

  def handle_event("select_ticket", %{"id" => id}, socket) do
    ticket_id = String.to_integer(id)
    ticket = Enum.find(socket.assigns.tickets, &(&1.id == ticket_id))
    logs = if ticket, do: Audit.list_logs_for_ticket(ticket.id), else: []

    {:noreply,
     socket
     |> assign(:selected_ticket, ticket)
     |> assign(:selected_logs, logs)}
  end

  def handle_event("close_timeline", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_ticket, nil)
     |> assign(:selected_logs, [])}
  end

  defp search_tickets(filters, assigns) do
    query = Tickets.Ticket

    query =
      if filters.code != "" do
        query |> where([t], ilike(t.display_code, ^"%#{filters.code}%"))
      else
        query
      end

    query =
      if filters.user_id != "" do
        user_id = String.to_integer(filters.user_id)
        query |> where([t], t.user_id == ^user_id)
      else
        query
      end

    query =
      if filters.status != "" do
        query |> where([t], t.status == ^filters.status)
      else
        query
      end

    query =
      if filters.date_start != "" do
        {:ok, date} = Date.from_iso8601(filters.date_start)
        dt = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        query |> where([t], t.inserted_at >= ^dt)
      else
        query
      end

    query =
      if filters.date_end != "" do
        {:ok, date} = Date.from_iso8601(filters.date_end)
        dt = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
        query |> where([t], t.inserted_at <= ^dt)
      else
        query
      end

    # Filter by establishment if impersonating
    query =
      if assigns[:selected_establishment_id] do
        query |> where([t], t.establishment_id == ^assigns.selected_establishment_id)
      else
        query
      end

    query
    |> order_by(desc: :inserted_at)
    |> limit(50)
    |> Repo.all()
    |> Repo.preload([:establishment, :user, :room])
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen text-white font-mono p-4 flex flex-col pt-20">
      <.app_header
        title="Ticket Tracking"
        show_home={true}
        current_scope={@current_scope}
        client_name={@client_name}
        establishment_name={if length(@establishments) == 0, do: @establishment_name}
        establishments={@establishments}
        users={@users}
        selected_establishment_id={@selected_establishment_id}
        selected_user_id={@selected_user_id}
        impersonating={@impersonating}
      />

      <div class="st-container flex-1 m-4" style="margin-top: 0;">
        <.page_header
          title="🎫 Ticket Tracking"
          description="Rastreie todo o histórico de tickets desde sua criação até a finalização."
          breadcrumb_items={[
            %{label: "Gerente", href: "/manager"},
            %{label: "Ticket Tracking"}
          ]}
        >
          <:actions>
            <.link navigate={~p"/manager"} class="btn btn-ghost btn-sm gap-2">
              <i class="fa-solid fa-arrow-left"></i> Voltar
            </.link>
          </:actions>
          
    <!-- Filters Card -->
          <div class="mt-6">
            <div class="backdrop-blur-xl bg-black/40 border border-white/10 rounded-2xl p-6 shadow-2xl">
              <h3 class="text-sm font-bold text-white/70 uppercase tracking-widest mb-4 flex items-center gap-2">
                <i class="fa-solid fa-filter text-orange-400"></i> Filtros
              </h3>
              <form phx-submit="filter" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
                <!-- Code Filter -->
                <div>
                  <label class="text-xs text-white/50 uppercase tracking-widest mb-1 block">
                    Código
                  </label>
                  <input
                    type="text"
                    name="code"
                    value={@filter_code}
                    placeholder="Ex: A001"
                    class="w-full bg-black/50 border border-white/20 rounded-lg px-3 py-2 text-white text-sm placeholder-white/30 focus:border-orange-500/50 focus:ring-1 focus:ring-orange-500/20"
                  />
                </div>
                
    <!-- User Filter -->
                <div>
                  <label class="text-xs text-white/50 uppercase tracking-widest mb-1 block">
                    Usuário
                  </label>
                  <select
                    name="user_id"
                    class="w-full bg-black/50 border border-white/20 rounded-lg px-3 py-2 text-white text-sm focus:border-orange-500/50"
                  >
                    <option value="">Todos</option>
                    <%= for user <- @all_users do %>
                      <option value={user.id} selected={to_string(user.id) == @filter_user_id}>
                        {user.email}
                      </option>
                    <% end %>
                  </select>
                </div>
                
    <!-- Status Filter -->
                <div>
                  <label class="text-xs text-white/50 uppercase tracking-widest mb-1 block">
                    Status
                  </label>
                  <select
                    name="status"
                    class="w-full bg-black/50 border border-white/20 rounded-lg px-3 py-2 text-white text-sm focus:border-orange-500/50"
                  >
                    <option value="">Todos</option>
                    <option value="WAITING_RECEPTION" selected={@filter_status == "WAITING_RECEPTION"}>
                      Aguardando Recepção
                    </option>
                    <option value="CALLED_RECEPTION" selected={@filter_status == "CALLED_RECEPTION"}>
                      Chamado Recepção
                    </option>
                    <option value="IN_RECEPTION" selected={@filter_status == "IN_RECEPTION"}>
                      Em Atendimento Recepção
                    </option>
                    <option
                      value="WAITING_PROFESSIONAL"
                      selected={@filter_status == "WAITING_PROFESSIONAL"}
                    >
                      Aguardando Atendimento
                    </option>
                    <option
                      value="CALLED_PROFESSIONAL"
                      selected={@filter_status == "CALLED_PROFESSIONAL"}
                    >
                      Chamado Atendimento
                    </option>
                    <option value="IN_ATTENDANCE" selected={@filter_status == "IN_ATTENDANCE"}>
                      Em Atendimento
                    </option>
                    <option value="FINISHED" selected={@filter_status == "FINISHED"}>
                      Finalizado
                    </option>
                  </select>
                </div>
                
    <!-- Date Range -->
                <div>
                  <label class="text-xs text-white/50 uppercase tracking-widest mb-1 block">
                    Data Início
                  </label>
                  <input
                    type="date"
                    name="date_start"
                    value={@filter_date_start}
                    class="w-full bg-black/50 border border-white/20 rounded-lg px-3 py-2 text-white text-sm focus:border-orange-500/50"
                  />
                </div>

                <div>
                  <label class="text-xs text-white/50 uppercase tracking-widest mb-1 block">
                    Data Fim
                  </label>
                  <div class="flex gap-2">
                    <input
                      type="date"
                      name="date_end"
                      value={@filter_date_end}
                      class="flex-1 bg-black/50 border border-white/20 rounded-lg px-3 py-2 text-white text-sm focus:border-orange-500/50"
                    />
                    <button
                      type="submit"
                      class="bg-gradient-to-r from-orange-600 to-amber-600 hover:from-orange-500 hover:to-amber-500 text-white font-bold px-4 py-2 rounded-lg transition-all"
                    >
                      <i class="fa-solid fa-search"></i>
                    </button>
                  </div>
                </div>
              </form>
            </div>
          </div>
          
    <!-- Results -->
          <div class="mt-6 grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Tickets List -->
            <div class="backdrop-blur-xl bg-black/40 border border-white/10 rounded-2xl p-6 shadow-2xl">
              <h3 class="text-sm font-bold text-white/70 uppercase tracking-widest mb-4 flex items-center gap-2">
                <i class="fa-solid fa-ticket text-orange-400"></i>
                Tickets
                <span class="bg-orange-900/50 text-orange-300 px-2 py-0.5 rounded text-xs">
                  {length(@tickets)}
                </span>
              </h3>

              <%= if Enum.empty?(@tickets) do %>
                <div class="text-center py-12 text-white/40">
                  <i class="fa-solid fa-search text-4xl mb-4 block"></i>
                  <p>Use os filtros acima para buscar tickets.</p>
                </div>
              <% else %>
                <div class="space-y-2 max-h-[500px] overflow-y-auto custom-scrollbar pr-2">
                  <%= for ticket <- @tickets do %>
                    <div
                      phx-click="select_ticket"
                      phx-value-id={ticket.id}
                      class={"p-3 rounded-xl border cursor-pointer transition-all " <>
                        if(@selected_ticket && @selected_ticket.id == ticket.id,
                          do: "bg-orange-500/20 border-orange-500/50",
                          else: "bg-white/5 border-white/10 hover:bg-white/10 hover:border-white/20")}
                    >
                      <div class="flex items-center justify-between">
                        <div class="flex items-center gap-3">
                          <span class="text-lg font-bold text-orange-400">{ticket.display_code}</span>
                          <span class={"text-xs font-bold px-2 py-0.5 rounded " <> status_badge(ticket.status)}>
                            {format_status(ticket.status)}
                          </span>
                        </div>
                        <span class="text-white/40 text-xs font-mono">
                          {Calendar.strftime(ticket.inserted_at, "%d/%m %H:%M")}
                        </span>
                      </div>
                      <div class="mt-1 text-sm text-white/60 truncate">
                        {ticket.customer_name || "Cliente não identificado"}
                      </div>
                      <%= if ticket.user do %>
                        <div class="mt-1 text-xs text-white/40">
                          <i class="fa-solid fa-user mr-1"></i>
                          {ticket.user.email}
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
            
    <!-- Timeline Panel -->
            <div class="backdrop-blur-xl bg-black/40 border border-white/10 rounded-2xl p-6 shadow-2xl">
              <%= if @selected_ticket do %>
                <div class="flex items-center justify-between mb-4">
                  <h3 class="text-sm font-bold text-white/70 uppercase tracking-widest flex items-center gap-2">
                    <i class="fa-solid fa-timeline text-orange-400"></i>
                    Timeline: {@selected_ticket.display_code}
                  </h3>
                  <button
                    phx-click="close_timeline"
                    class="text-white/40 hover:text-white transition-colors"
                  >
                    <i class="fa-solid fa-times"></i>
                  </button>
                </div>
                
    <!-- Ticket Summary -->
                <div class="bg-gradient-to-br from-orange-900/30 to-black/40 border border-orange-500/30 rounded-xl p-4 mb-4">
                  <div class="flex items-center gap-3">
                    <div class="w-12 h-12 bg-orange-500/20 rounded-lg flex items-center justify-center border border-orange-500/30">
                      <span class="text-lg font-bold text-orange-400">{@selected_ticket.display_code}</span>
                    </div>
                    <div>
                      <h4 class="font-bold text-white">
                        {@selected_ticket.customer_name || "Cliente não identificado"}
                      </h4>
                      <p class="text-xs text-white/60">
                        {Calendar.strftime(@selected_ticket.inserted_at, "%d/%m/%Y às %H:%M:%S")}
                      </p>
                    </div>
                  </div>
                </div>
                
    <!-- Events -->
                <div class="relative max-h-[400px] overflow-y-auto custom-scrollbar pr-2">
                  <div class="absolute left-3 top-0 bottom-0 w-px bg-gradient-to-b from-orange-500/50 via-white/20 to-emerald-500/50">
                  </div>

                  <div class="space-y-4">
                    <%= for {log, idx} <- Enum.with_index(@selected_logs) do %>
                      <% is_first = idx == 0
                      is_last = idx == length(@selected_logs) - 1 %>
                      <div class="relative pl-8">
                        <div class={[
                          "absolute left-0 w-6 h-6 rounded-full flex items-center justify-center border-2",
                          if(is_first,
                            do: "bg-orange-500/30 border-orange-500",
                            else:
                              if(is_last,
                                do: "bg-emerald-500/30 border-emerald-500",
                                else: "bg-white/10 border-white/30"
                              )
                          )
                        ]}>
                          <i class={"fa-solid text-[8px] " <> action_icon(log.action)}></i>
                        </div>

                        <div class="bg-white/5 border border-white/10 rounded-lg p-3">
                          <div class="flex items-center justify-between mb-1">
                            <span class={"text-xs font-bold " <> action_color(log.action)}>
                              {format_action(log.action)}
                            </span>
                            <span class="text-white/40 text-[10px] font-mono">
                              {Calendar.strftime(log.inserted_at, "%H:%M:%S")}
                            </span>
                          </div>
                          <%= if log.user do %>
                            <p class="text-[10px] text-white/40">{log.user.email}</p>
                          <% end %>
                          <%= if is_map(log.details) && Map.has_key?(log.details, "diff") do %>
                            <% diff = log.details["diff"] || %{} %>
                            <%= for {field, change} <- Enum.take(diff, 3) do %>
                              <div class="flex items-center gap-1 text-[10px] mt-1">
                                <span class="text-white/40">{humanize_field(field)}:</span>
                                <%= if is_map(change) && Map.has_key?(change, "to") do %>
                                  <span class="text-emerald-400">{format_value(change["to"])}</span>
                                <% end %>
                              </div>
                            <% end %>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% else %>
                <div class="text-center py-12 text-white/40">
                  <i class="fa-solid fa-timeline text-4xl mb-4 block"></i>
                  <p>Selecione um ticket para ver a timeline.</p>
                </div>
              <% end %>
            </div>
          </div>
        </.page_header>
      </div>
    </div>
    """
  end

  # Helper functions
  defp status_badge(status) do
    case status do
      "WAITING_RECEPTION" -> "bg-yellow-500/20 text-yellow-400"
      "CALLED_RECEPTION" -> "bg-orange-500/20 text-orange-400"
      "IN_RECEPTION" -> "bg-amber-500/20 text-amber-400"
      "WAITING_PROFESSIONAL" -> "bg-orange-500/20 text-orange-400"
      "CALLED_PROFESSIONAL" -> "bg-purple-500/20 text-purple-400"
      "IN_ATTENDANCE" -> "bg-indigo-500/20 text-indigo-400"
      "FINISHED" -> "bg-emerald-500/20 text-emerald-400"
      _ -> "bg-white/20 text-white/70"
    end
  end

  defp format_status(status) do
    case status do
      "WAITING_RECEPTION" -> "Aguardando"
      "CALLED_RECEPTION" -> "Chamado"
      "IN_RECEPTION" -> "Recepção"
      "WAITING_PROFESSIONAL" -> "Espera"
      "CALLED_PROFESSIONAL" -> "Chamado"
      "IN_ATTENDANCE" -> "Atendendo"
      "FINISHED" -> "Finalizado"
      _ -> status
    end
  end

  defp action_icon(action) do
    cond do
      String.contains?(action, "CREATED") -> "fa-plus text-orange-400"
      String.contains?(action, "PRINTED") -> "fa-print text-amber-400"
      String.contains?(action, "CALLED") -> "fa-phone text-yellow-400"
      String.contains?(action, "UPDATED") -> "fa-pen text-white/60"
      String.contains?(action, "SERVICES") -> "fa-list-check text-purple-400"
      String.contains?(action, "WEBCHECKIN") -> "fa-mobile text-green-400"
      String.contains?(action, "ERROR") -> "fa-triangle-exclamation text-red-400"
      true -> "fa-circle text-white/40"
    end
  end

  defp action_color(action) do
    cond do
      String.contains?(action, "CREATED") -> "text-orange-400"
      String.contains?(action, "PRINTED") -> "text-amber-400"
      String.contains?(action, "CALLED") -> "text-yellow-400"
      String.contains?(action, "SERVICES") -> "text-purple-400"
      String.contains?(action, "WEBCHECKIN") -> "text-green-400"
      String.contains?(action, "ERROR") -> "text-red-400"
      true -> "text-white/70"
    end
  end

  defp format_action(action) do
    action
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_field(field) when is_atom(field), do: humanize_field(Atom.to_string(field))

  defp humanize_field(field) do
    field
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_value(nil), do: "-"
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_integer(value), do: to_string(value)
  defp format_value(value) when is_boolean(value), do: if(value, do: "Sim", else: "Não")
  defp format_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_value(%DateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  defp format_value(value), do: inspect(value)
end
