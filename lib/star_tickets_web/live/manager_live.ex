defmodule StarTicketsWeb.ManagerLive do
  use StarTicketsWeb, :live_view

  alias StarTicketsWeb.ImpersonationHelpers

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    {:ok, assign(socket, impersonation_assigns)}
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
