defmodule StarTicketsWeb.Components.AppLayout do
  @moduledoc """
  Componentes de layout reutilizáveis: header e footer.
  """
  use Phoenix.Component
  use StarTicketsWeb, :verified_routes

  @doc """
  Header da aplicação com estilo acrílico.

  ## Slots
    * `:left` - Conteúdo do lado esquerdo (opcional, padrão: logo + título)
    * `:right` - Conteúdo do lado direito (opcional)

  ## Attrs
    * `:title` - Título da página (padrão: "Star Tickets")
    * `:show_home` - Mostrar botão home (padrão: false)
    * `:home_path` - Path do botão home (padrão: "/dashboard")
    * `:current_scope` - Scope do usuário atual (opcional)
  """
  attr(:title, :string, default: "Star Tickets")
  attr(:show_home, :boolean, default: false)
  attr(:home_path, :string, default: "/dashboard")
  attr(:current_scope, :any, default: nil)

  slot(:left)
  slot(:right)

  def app_header(assigns) do
    ~H"""
    <header class="st-app-header">
      <div class="st-header-left">
        <%= if @show_home do %>
          <a href={@home_path} class="st-home-btn">🏠</a>
        <% end %>
        <%= if @left != [] do %>
          <%= render_slot(@left) %>
        <% else %>
          <%= if @title == "Star Tickets" do %>
            <span class="text-2xl">🎫</span>
          <% end %>
          <h1><%= @title %></h1>
        <% end %>
      </div>
      <div class="st-header-right">
        <%= if @right != [] do %>
          <%= render_slot(@right) %>
        <% else %>
          <%= if @current_scope && @current_scope.user do %>
            <div class="st-user-profile">
              <span class="st-user-name"><%= @current_scope.user.name || @current_scope.user.email %></span>
              <span class="st-user-role"><%= format_role(@current_scope.user.role) %></span>
            </div>
            <a href="/users/log-out" data-method="delete" class="st-btn st-btn-acrylic st-btn-small">
              Sair
            </a>
          <% end %>
        <% end %>
      </div>
    </header>
    """
  end

  @doc """
  Footer da aplicação com estilo acrílico.
  """
  def app_footer(assigns) do
    ~H"""
    <footer class="st-acrylic" style="padding: 15px; text-align: center; margin-top: auto;">
      <p class="text-white/80 text-sm">
        © 2024 Star Tickets - Sistema de Gestão de Senhas
      </p>
    </footer>
    """
  end

  @doc """
  Breadcrumb de navegação.

  ## Attrs
    * `:items` - Lista de maps com :label e :href (opcional para o último)
  """
  attr(:items, :list, required: true)

  def breadcrumb(assigns) do
    ~H"""
    <nav class="st-text-subtitle text-sm">
      <.link navigate="/dashboard" class="st-text-hover">
        <i class="fa-solid fa-house"></i> Home
      </.link>
      <%= for {item, index} <- Enum.with_index(@items) do %>
        <span class="mx-2">/</span>
        <%= if index == length(@items) - 1 do %>
          <span class="st-text-title"><%= item.label %></span>
        <% else %>
          <.link navigate={item.href} class="st-text-hover"><%= item.label %></.link>
        <% end %>
      <% end %>
    </nav>
    """
  end

  @doc """
  Cabeçalho de página com breadcrumb, título e descrição.
  Serve também como container principal do conteúdo.
  """
  attr(:title, :string, required: true)
  attr(:description, :string, default: nil)
  attr(:breadcrumb_items, :list, required: true)
  slot(:inner_block, required: false)

  def page_header(assigns) do
    ~H"""
    <div class="mb-6 space-y-4 flex flex-col h-full">
      <div>
        <div class="st-card st-acrylic px-4 py-2 inline-block rounded-full">
          <.breadcrumb items={@breadcrumb_items} />
        </div>
      </div>

      <div class="st-card st-acrylic p-6 flex-1">
        <h1 class="text-2xl font-bold st-text-title"><%= @title %></h1>
        <p :if={@description} class="st-text-subtitle mt-1 mb-6"><%= @description %></p>

        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  @doc """
  Sidebar de administração com menu de navegação.
  """
  attr(:active, :string, default: nil)

  def admin_sidebar(assigns) do
    ~H"""
    <aside class="st-acrylic" style="width: 220px; min-height: calc(100vh - 80px); padding: 20px; position: fixed; left: 0; top: 80px; bottom: 0;">
      <h2 class="text-lg font-bold text-white mb-4 pb-2 border-b border-white/20">
        <i class="fa-solid fa-gear"></i> Menu
      </h2>
      <nav class="space-y-1">
        <a href="/admin/establishments" class={"st-admin-link #{if @active == "establishments", do: "active"}"}>
          <i class="fa-solid fa-building fa-fw"></i>
          <span>Estabelecimentos</span>
        </a>

        <a href="/admin/services" class={"st-admin-link #{if @active == "services", do: "active"}"}>
          <i class="fa-solid fa-wrench fa-fw"></i>
          <span>Serviços</span>
        </a>

        <a href="/admin/forms" class={"st-admin-link #{if @active == "forms", do: "active"}"}>
          <i class="fa-solid fa-clipboard-list fa-fw"></i>
          <span>Formulários</span>
        </a>

        <a href="/admin/rooms" class={"st-admin-link #{if @active == "rooms", do: "active"}"}>
          <i class="fa-solid fa-door-open fa-fw"></i>
          <span>Salas</span>
        </a>

        <a href="/admin/totems" class={"st-admin-link #{if @active == "totems", do: "active"}"}>
          <i class="fa-solid fa-ticket fa-fw"></i>
          <span>Totem</span>
        </a>

        <a href="/admin/users" class={"st-admin-link #{if @active == "users", do: "active"}"}>
          <i class="fa-solid fa-users fa-fw"></i>
          <span>Usuários</span>
        </a>
      </nav>
    </aside>
    """
  end

  @doc "Formata o role do usuário para exibição em português"
  def format_role(role) do
    case role do
      "admin" -> "Administrador"
      "manager" -> "Gerente"
      "receptionist" -> "Recepcionista"
      "professional" -> "Profissional"
      "tv" -> "Painel TV"
      "totem" -> "Totem"
      _ -> role || "Usuário"
    end
  end
end
