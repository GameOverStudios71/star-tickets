defmodule StarTicketsWeb.DashboardLive do
  use StarTicketsWeb, :live_view

  @menu_permissions %{
    "admin" => [:totem, :reception, :professional, :tv, :manager, :admin, :profile],
    "manager" => [:totem, :reception, :professional, :tv, :manager, :profile],
    "receptionist" => [:reception, :profile],
    "professional" => [:professional, :profile],
    "tv" => [:tv],
    "totem" => [:totem]
  }

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    allowed_pages = Map.get(@menu_permissions, user.role, [:profile])

    {:ok, assign(socket, allowed_pages: allowed_pages)}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col" style="padding-top: 100px;">
      <.app_header current_scope={@current_scope} />

      <%!-- Menu Grid --%>
      <div class="st-container">
        <div class="st-grid">
          <%= if :totem in @allowed_pages do %>
            <.link navigate={~p"/totem"} class="st-card st-nav-card">
              <span class="st-icon">🎫</span>
              <h2>Totem</h2>
              <p>Autoatendimento para clientes</p>
            </.link>
          <% end %>

          <%= if :manager in @allowed_pages do %>
            <.link navigate={~p"/manager"} class="st-card st-nav-card">
              <span class="st-icon">📊</span>
              <h2>Gerente</h2>
              <p>Otimização de filas e fluxo</p>
            </.link>
          <% end %>

          <%= if :reception in @allowed_pages do %>
            <.link navigate={~p"/reception"} class="st-card st-nav-card">
              <span class="st-icon">👥</span>
              <h2>Recepção</h2>
              <p>Gestão de filas e cadastro</p>
            </.link>
          <% end %>

          <%= if :tv in @allowed_pages do %>
            <.link navigate={~p"/tv"} class="st-card st-nav-card">
              <span class="st-icon">📺</span>
              <h2>Painel TV</h2>
              <p>Exibição de chamadas</p>
            </.link>
          <% end %>

          <%= if :professional in @allowed_pages do %>
            <.link navigate={~p"/professional"} class="st-card st-nav-card">
              <span class="st-icon">🏥</span>
              <h2>Profissional</h2>
              <p>Chamada e atendimento</p>
            </.link>
          <% end %>

          <%= if :admin in @allowed_pages do %>
            <.link navigate={~p"/admin"} class="st-card st-nav-card">
              <span class="st-icon">⚙️</span>
              <h2>Administração</h2>
              <p>Gestão do sistema</p>
            </.link>
          <% end %>

          <%= if :profile in @allowed_pages do %>
            <.link navigate={~p"/users/settings"} class="st-card st-nav-card">
              <span class="st-icon">👤</span>
              <h2>Meus Dados</h2>
              <p>Editar perfil e senha</p>
            </.link>
          <% end %>
        </div>
      </div>

      <.app_footer />
    </div>
    """
  end
end
