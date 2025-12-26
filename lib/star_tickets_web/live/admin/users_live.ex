defmodule StarTicketsWeb.Admin.UsersLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Accounts
  alias StarTickets.Accounts.User
  import StarTicketsWeb.AdminComponents

  alias StarTicketsWeb.ImpersonationHelpers

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    # Rename users to users_dropdown to avoid conflict with table data
    impersonation_assigns =
      Map.put(impersonation_assigns, :users_dropdown, impersonation_assigns.users)

    socket = assign(socket, impersonation_assigns)

    if scope = socket.assigns[:current_scope] do
      # If scoped to a client (e.g. manager/admin of a client), user can only see users of that client
      client_id = scope.user.client_id

      {:ok,
       assign(socket,
         client_id: client_id,
         show_confirm_modal: false,
         item_to_delete: nil
       )}
    else
      # Superadmin view (no scope) logic if needed, or default
      # Assuming mostly multi-tenant context for now
      {:ok,
       assign(socket,
         client_id: nil,
         show_confirm_modal: false,
         item_to_delete: nil
       )}
    end
  end

  def handle_params(params, _url, socket) do
    socket =
      socket
      |> apply_action(socket.assigns.live_action, params)
      |> assign_list(params)

    {:noreply, socket}
  end

  defp assign_list(socket, params) do
    page = String.to_integer(params["page"] || "1")
    search_term = params["search"] || ""

    # Sort users: Admins first, then by role, then by name
    filter_params = %{
      "page" => "#{page}",
      "per_page" => "10",
      "search" => search_term,
      "client_id" => socket.assigns.client_id
    }

    users =
      Accounts.list_users(filter_params)
      |> Enum.sort_by(fn user ->
        role_priority =
          case user.role do
            "admin" -> 0
            "manager" -> 1
            "reception" -> 2
            "professional" -> 3
            "tv" -> 4
            "totem" -> 5
            _ -> 99
          end

        {role_priority, user.name}
      end)

    # Need to pass map for count too
    count_params = %{
      "search" => search_term,
      "client_id" => socket.assigns.client_id
    }

    total_count = Accounts.count_users(count_params)
    total_pages = ceil(total_count / 10)

    assign(socket, users: users, total_pages: total_pages, page: page, search_term: search_term)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Editar Usuário")
    |> assign(:user, Accounts.get_user!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Novo Usuário")
    # Pre-fill client_id
    |> assign(:user, %User{client_id: socket.assigns.client_id})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Usuários")
    |> assign(:user, nil)
  end

  def handle_info(
        {StarTicketsWeb.Admin.Users.FormComponent, {:saved, _user, msg}},
        socket
      ) do
    {:noreply,
     socket
     |> put_flash(:success, msg)
     |> push_patch(to: ~p"/admin/users")}
  end

  def handle_event("search", %{"search" => search_term}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/users?search=#{search_term}")}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    params = %{search: socket.assigns.search_term, page: page}
    {:noreply, push_patch(socket, to: ~p"/admin/users?#{params}")}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col" style="padding-top: 80px;">
      <.flash kind={:info} title="Informação" flash={@flash} />
      <.flash kind={:success} title="Sucesso" flash={@flash} />
      <.flash kind={:warning} title="Atenção" flash={@flash} />
      <.flash kind={:error} title="Erro" flash={@flash} />
      <.flash kind={:delete} title="Excluído" flash={@flash} />

      <.app_header
        title="Administração"
        show_home={true}
        current_scope={@current_scope}
        client_name={@client_name}
        establishment_name={if length(@establishments) == 0, do: @establishment_name}
        establishments={@establishments}
        users={@users_dropdown}
        selected_establishment_id={@selected_establishment_id}
        selected_user_id={@selected_user_id}
        impersonating={@impersonating}
      />

      <div class="st-container flex-1 m-4">
        <.page_header
          title="👥 Usuários"
          description="Gerencie os usuários e suas permissões de acesso."
          breadcrumb_items={[
            %{label: "Administração", href: "/admin"},
            %{label: "Usuários"}
          ]}
        >
          <hr class="my-6 border-white/500 opacity-40 border-dashed" />

          <.action_header title="Lista de Usuários">
            <:actions>
              <.search_bar value={@search_term} />
              <.link patch={~p"/admin/users/new"} class="btn btn-primary h-10 min-h-0">
                <.icon name="hero-plus" class="mr-2" /> Novo
              </.link>
            </:actions>
          </.action_header>

          <.admin_table id="users" rows={@users}>
            <:col :let={user} label="Nome">
              <div class="flex flex-col">
                <span class="font-bold">{user.name}</span>
                <span class="text-xs text-base-content/60">@{user.username}</span>
              </div>
            </:col>
            <:col :let={user} label="Email">{user.email}</:col>
            <:col :let={user} label="Role">
              <span class={"st-badge " <> role_badge_class(user.role)}>
                {String.upcase(user.role)}
              </span>
            </:col>
            <:col :let={user} label="Estabelecimento">
              {if user.establishment, do: user.establishment.name, else: "Todos"}
            </:col>
            <:action :let={user}>
              <.link patch={~p"/admin/users/#{user}/edit"} class="btn btn-sm btn-ghost btn-square" title="Editar">
                <.icon name="hero-pencil-square" class="size-5 text-blue-400" />
              </.link>
              <button
                phx-click="confirm_delete"
                phx-value-id={user.id}
                class="btn btn-sm btn-ghost btn-square"
                title="Excluir"
              >
                <.icon name="hero-trash" class="size-5 text-red-400" />
              </button>
            </:action>
          </.admin_table>

          <.pagination page={@page} total_pages={@total_pages} />
        </.page_header>

        <.modal :if={@show_confirm_modal} id="confirm-modal" show={@show_confirm_modal} transparent={true} on_cancel={JS.push("cancel_delete")}>
          <div class="st-modal-confirm">
            <div class="st-modal-icon-container">
              <.icon name="hero-exclamation-triangle" class="size-12 text-red-500" />
            </div>
            <h3 class="st-modal-title">Excluir Usuário?</h3>
            <p class="st-modal-text">
              Tem certeza que deseja excluir o usuário <strong>{if @item_to_delete, do: Accounts.get_user!(@item_to_delete).name}</strong>? Esta ação não pode ser desfeita.
            </p>
            <div class="flex justify-center gap-3">
              <button
                phx-click="cancel_delete"
                class="st-modal-btn st-modal-btn-cancel"
              >
                Cancelar
              </button>
              <button
                phx-click="do_delete"
                class="st-modal-btn st-modal-btn-confirm"
              >
                Excluir
              </button>
            </div>
          </div>
        </.modal>
      </div>

      <.app_footer />

      <.modal :if={@live_action in [:new, :edit]} id="user-modal" transparent={true} show on_cancel={JS.patch(~p"/admin/users")}>
        <.live_component
          module={StarTicketsWeb.Admin.Users.FormComponent}
          id={@user.id || :new}
          title={@page_title}
          action={@live_action}
          user={@user}
          patch={~p"/admin/users"}
          current_user_scope={@current_scope}
        />
      </.modal>
    </div>
    """
  end

  def role_badge_class("admin"), do: "bg-red-500/30 text-red-200 border border-red-500/50"
  def role_badge_class("manager"), do: "bg-blue-900/50 text-blue-200 border border-blue-700/50"

  def role_badge_class("reception"),
    do: "bg-yellow-500/30 text-yellow-200 border border-yellow-500/50"

  def role_badge_class("professional"),
    do: "bg-green-500/30 text-green-200 border border-green-500/50"

  def role_badge_class("tv"), do: "bg-cyan-500/30 text-cyan-200 border border-cyan-500/50"

  def role_badge_class("totem"),
    do: "bg-purple-500/30 text-purple-200 border border-purple-500/50"

  def role_badge_class(_), do: "bg-gray-500/30 text-gray-200 border border-gray-500/50"

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_confirm_modal: true, item_to_delete: id)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_confirm_modal: false, item_to_delete: nil)}
  end

  def handle_event("do_delete", _params, socket) do
    id = socket.assigns.item_to_delete
    user = Accounts.get_user!(id)

    case Accounts.delete_user(user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:delete, "Usuário excluído com sucesso!")
         |> push_navigate(to: ~p"/admin/users")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:error, "Erro ao excluir usuário.")}
    end
  end
end
