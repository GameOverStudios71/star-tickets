defmodule StarTicketsWeb.ImpersonationComponent do
  @moduledoc """
  LiveComponent for user impersonation dropdowns in the header.
  Shows establishment and user dropdowns based on the real user's role.
  """
  use StarTicketsWeb, :live_component

  alias StarTickets.Accounts
  alias StarTickets.Accounts.Scope

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       establishments: [],
       users: [],
       selected_establishment_id: nil,
       selected_user_id: nil
     )}
  end

  @impl true
  def update(assigns, socket) do
    real_user = Scope.get_real_user(assigns.current_scope) || assigns.current_scope.user
    current_user = assigns.current_scope.user

    # Determine what to show based on real user's role
    can_switch_establishment = real_user.role == "admin"
    can_switch_user = real_user.role in ["admin", "manager"]

    # Load establishments for admin
    establishments =
      if can_switch_establishment do
        Accounts.list_establishments_for_dropdown(real_user.client_id)
      else
        []
      end

    # Determine which establishment to use for user list
    establishment_id =
      if can_switch_establishment do
        socket.assigns[:selected_establishment_id] || current_user.establishment_id
      else
        real_user.establishment_id
      end

    # Load users for the selected establishment
    users =
      if can_switch_user do
        Accounts.list_users_for_dropdown(establishment_id)
      else
        []
      end

    {:ok,
     assign(socket,
       current_scope: assigns.current_scope,
       real_user: real_user,
       can_switch_establishment: can_switch_establishment,
       can_switch_user: can_switch_user,
       establishments: establishments,
       users: users,
       selected_establishment_id: establishment_id,
       selected_user_id: current_user.id,
       impersonating: Scope.impersonating?(assigns.current_scope)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center gap-1">
      <%!-- Establishment dropdown (admin only) --%>
      <%= if @can_switch_establishment and length(@establishments) > 0 do %>
        <select
          phx-change="select_establishment"
          phx-target={@myself}
          class="st-input bg-white/10 text-white text-sm py-1 px-2 rounded border border-white/30 cursor-pointer"
        >
          <%= for est <- @establishments do %>
            <option value={est.id} selected={est.id == @selected_establishment_id}>
              <%= est.name %>
            </option>
          <% end %>
        </select>
      <% end %>

      <%!-- User dropdown (admin and manager) --%>
      <%= if @can_switch_user and length(@users) > 0 do %>
        <select
          phx-change="select_user"
          phx-target={@myself}
          class="st-input bg-white/10 text-white text-sm py-1 px-2 rounded border border-white/30 cursor-pointer"
        >
          <option value="">-- Navegar como --</option>
          <%= for user <- @users do %>
            <option value={user.id} selected={user.id == @selected_user_id}>
              <%= user.name %> (<%= user.role %>)
            </option>
          <% end %>
        </select>
      <% end %>

      <%!-- Exit impersonation button --%>
      <%= if @impersonating do %>
        <button
          phx-click="exit_impersonation"
          phx-target={@myself}
          class="text-xs text-yellow-300 hover:text-yellow-100 underline"
        >
          ⚠️ Sair da impersonação
        </button>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("select_establishment", %{"value" => establishment_id}, socket) do
    # Update users list for new establishment
    users = Accounts.list_users_for_dropdown(establishment_id)

    {:noreply,
     assign(socket,
       selected_establishment_id: establishment_id,
       users: users,
       selected_user_id: nil
     )}
  end

  @impl true
  def handle_event("select_user", %{"value" => ""}, socket) do
    # Empty selection, exit impersonation
    send(self(), {:exit_impersonation})
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_user", %{"value" => user_id}, socket) do
    # Notify parent to switch user context
    send(self(), {:impersonate_user, user_id})
    {:noreply, assign(socket, selected_user_id: user_id)}
  end

  @impl true
  def handle_event("exit_impersonation", _params, socket) do
    send(self(), {:exit_impersonation})
    {:noreply, socket}
  end
end
