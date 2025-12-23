defmodule StarTicketsWeb.AdminLive do
  use StarTicketsWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col" style="padding-top: 80px;">
      <.app_header title="Administração" show_home={true} current_scope={@current_scope} />

      <div class="st-container m-4">
        <.page_header
          title="⚙️ Painel de Administração"
          description="Gerencie todas as configurações do sistema."
          breadcrumb_items={[
            %{label: "Administração"}
          ]}
        >
          <div class="st-grid mt-6">
            <.link navigate={~p"/admin/establishments"} class="st-card st-nav-card">
              <span class="st-icon">🏢</span>
              <h2>Estabelecimentos</h2>
              <p>Gerencie as unidades da empresa</p>
            </.link>

            <.link navigate={~p"/admin/services"} class="st-card st-nav-card">
              <span class="st-icon">🔧</span>
              <h2>Serviços</h2>
              <p>Cadastro de serviços oferecidos</p>
            </.link>

            <.link navigate={~p"/admin/forms"} class="st-card st-nav-card">
              <span class="st-icon">📝</span>
              <h2>Formulários</h2>
              <p>Formulários de atendimento</p>
            </.link>

            <.link navigate={~p"/admin/rooms"} class="st-card st-nav-card">
              <span class="st-icon">🚪</span>
              <h2>Salas</h2>
              <p>Salas e guichês de atendimento</p>
            </.link>

            <.link navigate={~p"/admin/totems"} class="st-card st-nav-card">
              <span class="st-icon">🎫</span>
              <h2>Totem</h2>
              <p>Configuração dos terminais</p>
            </.link>

            <.link navigate={~p"/admin/users"} class="st-card st-nav-card">
              <span class="st-icon">👥</span>
              <h2>Usuários</h2>
              <p>Gestão de usuários e permissões</p>
            </.link>
          </div>
        </.page_header>
      </div>

      <.app_footer />
    </div>
    """
  end
end
