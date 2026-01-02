defmodule StarTicketsWeb.DashboardLive do
  use StarTicketsWeb, :live_view

  alias StarTicketsWeb.Authorization
  alias StarTicketsWeb.Presence
  alias StarTickets.Accounts
  alias StarTickets.Accounts.Scope

  @presence_topic "system:presence"

  def mount(_params, session, socket) do
    scope = socket.assigns.current_scope
    user = scope.user
    real_user = Scope.get_real_user(scope) || user

    # Subscribe to presence updates for realtime count
    if connected?(socket) do
      Phoenix.PubSub.subscribe(StarTickets.PubSub, @presence_topic)
    end

    # Get initial presence count
    online_users = get_online_users()

    # Check if user can impersonate
    can_impersonate = real_user.role in ["admin", "manager"]

    # Load client
    client = if real_user.client_id, do: Accounts.get_client!(real_user.client_id), else: nil

    # Load establishments for admin
    establishments =
      if real_user.role == "admin" do
        Accounts.list_establishments_for_dropdown(real_user.client_id)
      else
        []
      end

    # Determine which establishment to use for user list
    # Priority: session saved > real_user's > first available
    session_establishment_id = session["selected_establishment_id"]

    establishment_for_users =
      cond do
        session_establishment_id != nil ->
          session_establishment_id

        real_user.establishment_id != nil ->
          real_user.establishment_id

        real_user.role == "admin" and length(establishments) > 0 ->
          hd(establishments).id

        true ->
          nil
      end

    # Load users for the selected establishment
    users =
      if can_impersonate and establishment_for_users != nil do
        Accounts.list_users_for_dropdown(establishment_for_users)
      else
        []
      end

    # Load establishment info (for display - show impersonated user's establishment)
    establishment =
      if user.establishment_id do
        Accounts.get_establishment!(user.establishment_id)
      else
        nil
      end

    # Filter out dashboard from menu since we're already here
    menu_items =
      Authorization.menu_items_for_role(user.role)
      |> Enum.reject(fn item -> item.key == :dashboard end)

    {:ok,
     assign(socket,
       menu_items: menu_items,
       client: client,
       establishment: establishment,
       can_impersonate: can_impersonate,
       establishments: establishments,
       users: users,
       selected_establishment_id: establishment_for_users,
       selected_user_id: if(Scope.impersonating?(scope), do: user.id, else: nil),
       impersonating: Scope.impersonating?(scope),
       online_users: online_users
     )}
  end

  # Handle presence diffs
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, online_users: get_online_users())}
  end

  defp get_online_users do
    Presence.list(@presence_topic)
    |> Enum.map(fn {user_id, %{metas: metas}} ->
      %{
        id: user_id,
        name: List.first(metas)[:name] || "Unknown",
        role: List.first(metas)[:role] || "unknown"
      }
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-20">
      <.app_header
        current_scope={@current_scope}
        client_name={@client && @client.name}
        establishment_name={@establishment && @establishment.name}
        establishments={@establishments}
        users={@users}
        selected_establishment_id={@selected_establishment_id}
        selected_user_id={@selected_user_id}
        impersonating={@impersonating}
      />

      <%!-- Menu Grid --%>
      <div class="st-container" style="margin-top: 0;">
        <%!-- Online Users Status Bar --%>
        <div class="mb-6 flex justify-center">
          <div class="inline-flex items-center gap-3 px-5 py-2.5 rounded-full bg-black/40 border border-white/10 backdrop-blur-xl shadow-lg">
            <span class="relative flex h-2.5 w-2.5">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-500 opacity-75">
              </span>
              <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
            </span>
            <span class="text-emerald-300/90 text-sm font-medium">
              {length(@online_users)} usuário(s) online
            </span>
            <%!-- Avatars of online users (limit to 5) --%>
            <div class="flex -space-x-2">
              <%= for user <- Enum.take(@online_users, 5) do %>
                <div
                  class="w-7 h-7 rounded-full bg-gradient-to-br from-white/20 to-white/5 border border-white/20 flex items-center justify-center text-xs font-bold text-white"
                  title={user.name}
                >
                  {String.first(user.name || "?")}
                </div>
              <% end %>
              <%= if length(@online_users) > 5 do %>
                <div class="w-7 h-7 rounded-full bg-white/10 border border-white/20 flex items-center justify-center text-xs text-white/70">
                  +{length(@online_users) - 5}
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-white mb-2">
            Bem-vindo, {@current_scope.user.name || @current_scope.user.email}!
          </h1>
          <p class="text-white/70">Selecione uma opção abaixo para começar</p>
        </div>

        <div class="flex flex-wrap justify-center gap-6">
          <%= for item <- @menu_items do %>
            <.link navigate={item.href} class="st-card st-nav-card w-64">
              <span class="st-icon">{icon_for_key(item.key)}</span>
              <h2>{item.label}</h2>
              <p>{description_for_key(item.key)}</p>
            </.link>
          <% end %>

          <%!-- Settings only for human users and NOT when impersonating --%>
          <%= if @current_scope.user.role not in ["tv", "totem"] and not @impersonating do %>
            <.link navigate={~p"/users/settings"} class="st-card st-nav-card w-64">
              <span class="st-icon">👤</span>
              <h2>Meus Dados</h2>
              <p>Editar perfil e senha</p>
            </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Handle establishment selection (admin only)
  # Select sends params as %{"establishment_id" => value} or %{"value" => value}
  def handle_event("select_establishment", params, socket) do
    establishment_id = params["establishment_id"] || params["value"]

    if establishment_id && establishment_id != "" do
      users = Accounts.list_users_for_dropdown(establishment_id)
      establishment = Accounts.get_establishment!(establishment_id)

      {:noreply,
       assign(socket,
         selected_establishment_id: establishment_id,
         users: users,
         establishment: establishment
       )}
    else
      {:noreply, socket}
    end
  end

  defp icon_for_key(:dashboard), do: "📊"
  defp icon_for_key(:admin), do: "⚙️"
  defp icon_for_key(:manager), do: "📈"
  defp icon_for_key(:reception), do: "👥"
  defp icon_for_key(:professional), do: "🏥"
  defp icon_for_key(:tv), do: "📺"
  defp icon_for_key(:totem), do: "🎫"
  defp icon_for_key(_), do: "📄"

  defp description_for_key(:dashboard), do: "Visão geral do sistema"
  defp description_for_key(:admin), do: "Gestão do sistema"
  defp description_for_key(:manager), do: "Otimização de filas e fluxo"
  defp description_for_key(:reception), do: "Gestão de filas e cadastro"
  defp description_for_key(:professional), do: "Chamada e atendimento"
  defp description_for_key(:tv), do: "Exibição de chamadas"
  defp description_for_key(:totem), do: "Autoatendimento para clientes"
  defp description_for_key(_), do: ""
end
