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
  attr(:client_name, :string, default: nil)
  attr(:establishment_name, :string, default: nil)
  # Impersonation attributes
  attr(:establishments, :list, default: [])
  attr(:users, :list, default: [])
  attr(:selected_establishment_id, :any, default: nil)
  attr(:selected_user_id, :any, default: nil)
  attr(:impersonating, :boolean, default: false)

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
          {render_slot(@left)}
        <% else %>
          <%= if @title == "Star Tickets" do %>
            <span class="text-2xl">🎫</span>
          <% end %>
          <h1>{@title}</h1>
        <% end %>
      </div>

      <%!-- Center section: Client and Establishment --%>
      <div class="st-header-center flex flex-col items-center">
        <%= if @client_name do %>
          <span class="text-white font-bold text-lg">{@client_name}</span>
        <% end %>
        <%!-- Show dropdown for establishments if available, otherwise show name --%>
        <%= if length(@establishments) > 0 do %>
          <form action="/select-establishment" method="post" id="establishment-form">
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <select
              name="establishment_id"
              onchange="this.form.submit()"
              class="bg-white/10 text-white text-sm py-1 px-3 rounded cursor-pointer border-none outline-none [&>option]:bg-neutral-900 [&>option]:text-white"
            >
              <%= for est <- @establishments do %>
                <option
                  value={est.id}
                  selected={to_string(est.id) == to_string(@selected_establishment_id)}
                >
                  {est.name}
                </option>
              <% end %>
            </select>
          </form>
        <% else %>
          <%= if @establishment_name do %>
            <span class="text-white/70 text-sm">{@establishment_name}</span>
          <% end %>
        <% end %>
      </div>

      <div class="st-header-right flex items-center gap-4">
        <%= if @right != [] do %>
          {render_slot(@right)}
        <% end %>

        <%= if @current_scope && @current_scope.user do %>
          <div class="st-user-profile flex items-center gap-3">
            <%!-- Show dropdown for users if available, otherwise show name --%>
            <%= if length(@users) > 0 do %>
              <form action="/impersonate" method="post" id="impersonation-form">
                <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
                <select
                  name="user_id"
                  onchange="this.form.submit()"
                  class="bg-white/10 text-white text-sm py-1 px-3 rounded cursor-pointer border-none outline-none [&>option]:bg-neutral-900 [&>option]:text-white"
                >
                  <option value="">-- Navegar como --</option>
                  <%= for user <- @users do %>
                    <option
                      value={user.id}
                      selected={to_string(user.id) == to_string(@selected_user_id)}
                    >
                      {user.name} ({user.role})
                    </option>
                  <% end %>
                </select>
              </form>
            <% else %>
              <span class="st-user-name text-white font-medium">
                {@current_scope.user.name || @current_scope.user.email}
              </span>
            <% end %>
            <span class={"text-xs px-2 py-0.5 rounded-full " <> role_badge_class(@current_scope.user.role)}>
              {format_role(@current_scope.user.role)}
            </span>
            <%= if @impersonating do %>
              <form action="/impersonate" method="post" style="display: inline;">
                <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
                <input type="hidden" name="_method" value="delete" />
                <button type="submit" class="text-xs text-yellow-300 hover:text-yellow-100">
                  ⚠️ Sair
                </button>
              </form>
            <% end %>
          </div>
          <form action="/users/log-out" method="post" style="display: inline;">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <button type="submit" class="st-btn st-btn-acrylic st-btn-small">
              Sair
            </button>
          </form>
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
  Menu de navegação principal filtrado por permissões do usuário.
  Só mostra links para páginas que o usuário tem acesso.
  """
  attr(:current_scope, :any, required: true)
  attr(:class, :string, default: "")

  def role_menu(assigns) do
    alias StarTicketsWeb.Authorization

    role = assigns.current_scope && assigns.current_scope.user && assigns.current_scope.user.role
    menu_items = if role, do: Authorization.menu_items_for_role(role), else: []
    assigns = Map.put(assigns, :menu_items, menu_items)

    ~H"""
    <nav class={"flex gap-2 flex-wrap " <> @class}>
      <%= for item <- @menu_items do %>
        <a
          href={item.href}
          class="st-btn st-btn-acrylic st-btn-small flex items-center gap-2"
        >
          <span class="text-lg">{icon_for_key(item.key)}</span>
          {item.label}
        </a>
      <% end %>
    </nav>
    """
  end

  defp icon_for_key(:dashboard), do: "📊"
  defp icon_for_key(:admin), do: "⚙️"
  defp icon_for_key(:manager), do: "📈"
  defp icon_for_key(:reception), do: "🎫"
  defp icon_for_key(:professional), do: "👤"
  defp icon_for_key(:tv), do: "📺"
  defp icon_for_key(:totem), do: "🖥️"
  defp icon_for_key(_), do: "📄"

  @doc """
  Breadcrumb de navegação.

  ## Attrs
    * `:items` - Lista de maps com :label e :href (opcional para o último)
  """
  attr(:items, :list, required: true)

  def breadcrumb(assigns) do
    ~H"""
    <nav class="st-text-subtitle text-sm flex items-center wrap">
      <.link
        navigate="/dashboard"
        class="text-gray-400 hover:text-blue-300 hover:underline transition-colors flex items-center gap-1"
      >
        <i class="fa-solid fa-house"></i> Home
      </.link>
      <%= for {item, index} <- Enum.with_index(@items) do %>
        <span class="mx-2 text-gray-600">/</span>
        <%= if index == length(@items) - 1 do %>
          <span class="text-white font-semibold">{item.label}</span>
        <% else %>
          <.link
            navigate={item.href}
            class="text-gray-400 hover:text-blue-300 hover:underline transition-colors"
          >
            {item.label}
          </.link>
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
  slot(:actions)

  def page_header(assigns) do
    ~H"""
    <div class="mb-6 space-y-4 flex flex-col h-full">
      <div>
        <div class="st-card st-acrylic px-4 py-2 inline-block rounded-full">
          <.breadcrumb items={@breadcrumb_items} />
        </div>
      </div>

      <div class="st-card st-acrylic p-6 flex-1">
        <h1 class="text-2xl font-bold st-text-title">{@title}</h1>
        <p :if={@description} class="st-text-subtitle mt-1 mb-6">{@description}</p>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc "Formata o role do usuário para exibição em português"
  def format_role(role) do
    case role do
      "admin" -> "Administrador"
      "manager" -> "Gerente"
      "reception" -> "Recepção"
      "professional" -> "Profissional"
      "tv" -> "Painel TV"
      "totem" -> "Totem"
      _ -> role || "Usuário"
    end
  end

  # Retorna classes CSS para badge de role no header
  defp role_badge_class("admin"), do: "bg-red-500/30 text-red-200 border border-red-500/50"
  defp role_badge_class("manager"), do: "bg-blue-900/50 text-blue-200 border border-blue-700/50"

  defp role_badge_class("reception"),
    do: "bg-yellow-500/30 text-yellow-200 border border-yellow-500/50"

  defp role_badge_class("professional"),
    do: "bg-green-500/30 text-green-200 border border-green-500/50"

  defp role_badge_class("tv"), do: "bg-cyan-500/30 text-cyan-200 border border-cyan-500/50"

  defp role_badge_class("totem"),
    do: "bg-purple-500/30 text-purple-200 border border-purple-500/50"

  defp role_badge_class(_), do: "bg-gray-500/30 text-gray-200 border border-gray-500/50"
end
