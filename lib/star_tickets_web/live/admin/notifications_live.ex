defmodule StarTicketsWeb.NotificationsLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Audit
  alias StarTicketsWeb.ImpersonationHelpers

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    socket =
      socket
      |> assign(impersonation_assigns)
      |> assign(:page_title, "Centro de Notificações")
      # Filter defaults
      |> assign(:severity, "alerts")
      |> assign(:search, "")
      |> assign(:loading, false)

    {:ok, load_notifications(socket)}
  end

  def handle_params(params, _url, socket) do
    severity = params["severity"] || "alerts"
    search = params["search"] || ""

    socket =
      socket
      |> assign(:severity, severity)
      |> assign(:search, search)
      |> load_notifications()

    {:noreply, socket}
  end

  def handle_event("filter_severity", %{"severity" => severity}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/notifications?severity=#{severity}&search=#{socket.assigns.search}"
     )}
  end

  def handle_event("search", %{"value" => query}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/notifications?severity=#{socket.assigns.severity}&search=#{query}"
     )}
  end

  defp load_notifications(socket) do
    # We map severity param to the filter expected by Audit context context

    filter_params =
      %{}
      |> Map.merge(
        if socket.assigns.severity != "all",
          do: %{"severity" => socket.assigns.severity},
          else: %{}
      )
      |> Map.merge(
        if socket.assigns.search != "", do: %{"action" => socket.assigns.search}, else: %{}
      )
      |> Map.put("page_size", 50)

    logs = Audit.list_logs(filter_params)
    assign(socket, :notifications, logs)
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-20">
      <.app_header
        title="Notificações"
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
          title="📬 Centro de Notificações"
          description="Histórico completo de alertas, erros e avisos do sistema."
          breadcrumb_items={[
            %{label: "Gerente", href: ~p"/manager"},
            %{label: "Notificações"}
          ]}
        >
          <!-- Filters Toolbar -->
          <div class="mt-6 flex flex-col md:flex-row gap-4 justify-between items-center bg-black/40 p-4 rounded-xl border border-white/10 backdrop-blur-md">
            
    <!-- Severity Filter -->
            <div class="flex gap-2">
              <button
                phx-click="filter_severity"
                phx-value-severity="alerts"
                class={"px-4 py-2 rounded-lg text-sm font-bold transition-all " <> if(@severity == "alerts", do: "bg-white text-black shadow-[0_0_15px_rgba(255,255,255,0.3)]", else: "bg-white/5 text-white/60 hover:bg-white/10 hover:text-white")}
              >
                Alertas
              </button>
              <button
                phx-click="filter_severity"
                phx-value-severity="error"
                class={"px-4 py-2 rounded-lg text-sm font-bold transition-all " <> if(@severity == "error", do: "bg-red-500 text-white shadow-[0_0_15px_rgba(239,68,68,0.5)]", else: "bg-white/5 text-red-400/60 hover:bg-red-950/50 hover:text-red-400")}
              >
                Erros
              </button>
              <button
                phx-click="filter_severity"
                phx-value-severity="warning"
                class={"px-4 py-2 rounded-lg text-sm font-bold transition-all " <> if(@severity == "warning", do: "bg-amber-500 text-black shadow-[0_0_15px_rgba(245,158,11,0.5)]", else: "bg-white/5 text-amber-400/60 hover:bg-amber-950/50 hover:text-amber-400")}
              >
                Avisos
              </button>
              <button
                phx-click="filter_severity"
                phx-value-severity="all"
                class={"px-4 py-2 rounded-lg text-sm font-bold transition-all " <> if(@severity == "all", do: "bg-cyan-900/50 text-cyan-200 border border-cyan-700/50", else: "bg-white/5 text-white/40 hover:bg-white/10 hover:text-white")}
              >
                <i class="fa-solid fa-list-ul mr-1"></i> Todos
              </button>
            </div>
            
    <!-- Search -->
            <div class="relative w-full md:w-64">
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <i class="fa-solid fa-search text-white/30"></i>
              </div>
              <input
                type="text"
                name="search"
                value={@search}
                placeholder="Buscar em alertas..."
                phx-keyup="search"
                phx-debounce="500"
                class="block w-full pl-10 pr-3 py-2 border border-white/10 rounded-lg leading-5 bg-black/50 text-white placeholder-white/30 focus:outline-none focus:ring-1 focus:ring-cyan-500 focus:border-cyan-500 sm:text-sm transition-all"
              />
            </div>
          </div>
          
    <!-- Notifications List -->
          <div class="mt-6 space-y-3">
            <%= if Enum.empty?(@notifications) do %>
              <div class="flex flex-col items-center justify-center p-12 text-white/30 border border-white/5 rounded-xl bg-black/20">
                <i class="fa-regular fa-folder-open text-5xl mb-4 opacity-50"></i>
                <p class="text-lg">Nenhum registro encontrado para este filtro.</p>
              </div>
            <% else %>
              <%= for log <- @notifications do %>
                <div class="group relative bg-black/40 border border-white/5 hover:border-white/20 rounded-xl p-4 transition-all hover:bg-white/5 overflow-hidden">
                  <!-- Decorator Bar based on severity logic -->
                  <% is_error =
                    String.contains?(log.action, "ERROR") or String.contains?(log.action, "FAILED")

                  is_warning =
                    String.contains?(log.action, "WARNING") or String.contains?(log.action, "ALERT")

                  {border_color, icon_color, icon, bg_glow} =
                    cond do
                      is_error ->
                        {"border-red-500/50", "text-red-400", "fa-triangle-exclamation",
                         "bg-red-500/5"}

                      is_warning ->
                        {"border-amber-500/50", "text-amber-400", "fa-bell", "bg-amber-500/5"}

                      true ->
                        {"border-cyan-500/30", "text-cyan-400", "fa-info-circle", "bg-cyan-500/5"}
                    end %>

                  <div class={"absolute left-0 top-0 bottom-0 w-1 #{border_color} bg-current"}></div>
                  <div class={"absolute inset-0 pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-700 #{bg_glow}"}>
                  </div>

                  <div class="flex items-start gap-4 relative z-10">
                    <div class={"mt-1 w-10 h-10 rounded-full flex items-center justify-center bg-white/5 border border-white/10 #{icon_color}"}>
                      <i class={"fa-solid #{icon} text-lg"}></i>
                    </div>

                    <div class="flex-1 min-w-0">
                      <div class="flex justify-between items-start">
                        <h3 class={"text-lg font-bold #{if is_error, do: "text-red-300", else: "text-white"} truncate pr-4"}>
                          {log.action}
                        </h3>
                        <span class="text-xs font-mono text-white/40 whitespace-nowrap bg-black/40 px-2 py-1 rounded border border-white/5">
                          {Calendar.strftime(log.inserted_at, "%d/%m/%Y %H:%M:%S")}
                        </span>
                      </div>

                      <div class="mt-2 flex flex-wrap gap-2 text-xs">
                        <span class="px-2 py-0.5 rounded bg-white/5 text-white/60 border border-white/10">
                          ID: {log.id}
                        </span>
                        <%= if log.user do %>
                          <span class="px-2 py-0.5 rounded bg-indigo-500/10 text-indigo-300 border border-indigo-500/20 flex items-center gap-1">
                            <i class="fa-solid fa-user"></i> {log.user.name}
                          </span>
                        <% end %>
                        <%= if log.resource_type do %>
                          <span class="px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-300 border border-emerald-500/20 flex items-center gap-1">
                            <i class="fa-solid fa-database"></i> {log.resource_type} #{log.resource_id}
                          </span>
                        <% end %>
                      </div>

                      <div class="mt-3 bg-black/50 rounded-lg p-3 border border-white/5 font-mono text-xs text-white/70 overflow-x-auto">
                        <div class="opacity-70">
                          {inspect(log.details, pretty: true, width: 80)}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </.page_header>
      </div>
    </div>
    """
  end
end
