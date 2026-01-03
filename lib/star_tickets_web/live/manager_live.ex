defmodule StarTicketsWeb.ManagerLive do
  use StarTicketsWeb, :live_view

  alias StarTicketsWeb.ImpersonationHelpers
  alias StarTickets.Sentinel.Overseer
  alias Phoenix.PubSub

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    if connected?(socket) do
      PubSub.subscribe(StarTickets.PubSub, "sentinel_events")
    end

    initial_anomalies =
      if connected?(socket) do
        Overseer.get_state().anomalies
      else
        []
      end

    socket =
      socket
      |> assign(impersonation_assigns)
      |> assign(:anomalies, initial_anomalies)

    {:ok, socket}
  end

  def handle_info({:sentinel_update, state}, socket) do
    {:noreply, assign(socket, :anomalies, state.anomalies)}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-20">
      <.app_header
        title="Gerente"
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
          title="📊 Painel do Gerente"
          description="Otimização de filas e monitoramento de fluxo."
          breadcrumb_items={[
            %{label: "Gerente"}
          ]}
        >
          <hr class="my-6 border-white/500 opacity-40 border-dashed" />

          <div class="st-grid mt-6">
            <.link navigate={~p"/admin/audit"} class="st-card st-nav-card">
              <span class="st-icon">🛡️</span>
              <h2>Auditoria</h2>
              <p>Logs forenses e rastreamento</p>
            </.link>

            <.link
              navigate={~p"/admin/sentinel"}
              class="st-card st-nav-card group relative overflow-hidden ring-1 ring-cyan-500/30"
            >
              <div class="absolute inset-0 bg-cyan-900/10 group-hover:bg-cyan-900/20 transition-colors">
              </div>
              <span class="st-icon relative z-10 animate-pulse drop-shadow-[0_0_10px_rgba(34,211,238,0.5)]">
                🔮
              </span>
              <h2 class="relative z-10 text-cyan-300 group-hover:text-cyan-200">Sentinel AI</h2>
              <p class="relative z-10 text-cyan-400/60 group-hover:text-cyan-300/80">
                Monitoramento & Projeções
              </p>
            </.link>
            
    <!-- MailBox / Notifications -->
            <.link
              navigate={~p"/admin/notifications"}
              class="st-card st-nav-card group relative overflow-hidden bg-gradient-to-br from-gray-900 to-black border border-white/10 cursor-pointer flex flex-col"
            >
              <div class="flex justify-between items-start relative z-10 shrink-0">
                <span class="st-icon transition-transform group-hover:scale-110">
                  📬
                </span>

                <%= if length(@anomalies) > 0 do %>
                  <div class="flex flex-col items-end">
                    <span class="bg-red-500 text-white text-[10px] font-bold px-2 py-0.5 rounded-full animate-pulse shadow-lg shadow-red-500/50 mb-1">
                      {length(@anomalies)}
                    </span>
                  </div>
                <% end %>
              </div>

              <div class="relative z-10 flex-1 min-h-0 flex flex-col">
                <h2 class="text-white group-hover:text-emerald-300 transition-colors mb-1 shrink-0">
                  Caixa de Entrada
                </h2>

                <%= if Enum.empty?(@anomalies) do %>
                  <p class="text-white/60 text-sm group-hover:text-white/80">
                    Histórico de alertas e notificações
                  </p>
                <% else %>
                  <!-- Mini Inbox List (Compact) -->
                  <div class="flex-1 overflow-hidden space-y-1 pt-1 opacity-80 pointer-events-none group-hover:opacity-100 transition-opacity">
                    <%= for {anomaly, _idx} <- Enum.take(Enum.with_index(@anomalies), 3) do %>
                      <div class="bg-white/5 px-2 py-1 rounded border border-white/10 flex justify-between items-center gap-2">
                        <p class="text-red-300 text-[9px] font-bold truncate flex-1">
                          {anomaly.action}
                        </p>
                        <p class="text-white/40 text-[9px] font-mono whitespace-nowrap">
                          {Calendar.strftime(anomaly.inserted_at, "%H:%M")}
                        </p>
                      </div>
                    <% end %>

                    <%= if length(@anomalies) > 3 do %>
                      <div class="text-[9px] text-white/40 italic text-right px-1">
                        + {length(@anomalies) - 3} outros...
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
              
    <!-- Background Glow -->
              <div class="absolute -bottom-4 -right-4 w-24 h-24 bg-emerald-500/10 blur-2xl rounded-full group-hover:bg-emerald-500/20 transition-all">
              </div>
            </.link>
            <!-- Notification Settings -->
            <.link
              navigate={~p"/admin/notification-settings"}
              class="st-card st-nav-card group relative overflow-hidden bg-gradient-to-br from-slate-900 to-black border border-white/10 cursor-pointer"
            >
              <div class="absolute inset-0 bg-blue-500/5 group-hover:bg-blue-500/10 transition-colors">
              </div>
              <span class="st-icon group-hover:rotate-90 transition-transform duration-700">⚙️</span>
              <h2 class="group-hover:text-blue-300 transition-colors">Painel de Controle</h2>
              <p class="text-white/60 group-hover:text-white/80">Configurar alertas e notificações</p>
            </.link>
            
    <!-- Placeholder for other manager tasks -->
            <.link navigate={~p"/dashboard"} class="st-card st-nav-card opacity-50 cursor-not-allowed">
              <span class="st-icon">📈</span>
              <h2>Relatórios (Breve)</h2>
              <p>Métricas de atendimento</p>
            </.link>
          </div>
        </.page_header>
      </div>
    </div>
    """
  end
end
