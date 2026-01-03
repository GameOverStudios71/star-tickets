defmodule StarTicketsWeb.Admin.RoomsLive do
  use StarTicketsWeb, :live_view

  alias StarTicketsWeb.ImpersonationHelpers
  alias StarTickets.Accounts
  alias StarTickets.Accounts.Room
  import StarTicketsWeb.AdminComponents

  @impl true
  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    socket =
      socket
      |> assign(impersonation_assigns)
      |> assign(:page_title, "Salas")
      |> assign(:room, nil)
      |> assign(:params, %{})
      |> assign(show_confirm_modal: false, item_to_delete: nil)

    if socket.assigns.selected_establishment_id do
      rooms = Accounts.list_rooms(socket.assigns.selected_establishment_id)
      {:ok, assign(socket, :rooms, rooms)}
    else
      {:ok, assign(socket, :rooms, [])}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> apply_action(socket.assigns.live_action, params)
      |> assign_list(params)

    {:noreply, socket}
  end

  defp assign_list(socket, params) do
    if establishment_id = socket.assigns.selected_establishment_id do
      rooms = Accounts.list_rooms(establishment_id, params)
      assign(socket, rooms: rooms, params: params)
    else
      assign(socket, rooms: [], params: params)
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Editar Sala")
    |> assign(:room, Accounts.get_room!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Nova Sala")
    |> assign(:room, %Room{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Salas")
    |> assign(:room, nil)
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_confirm_modal: true, item_to_delete: id)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_confirm_modal: false, item_to_delete: nil)}
  end

  def handle_event("do_delete", _params, socket) do
    id = socket.assigns.item_to_delete
    room = Accounts.get_room!(id)

    case Accounts.delete_room(room) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:delete, "Sala excluída com sucesso!")
         |> assign_list(socket.assigns.params)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:error, "Erro ao excluir sala.")}
    end
  end

  @impl true
  def handle_info({StarTicketsWeb.Admin.Rooms.FormComponent, {:saved, _room}}, socket) do
    rooms = Accounts.list_rooms(socket.assigns.selected_establishment_id)
    {:noreply, assign(socket, :rooms, rooms)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-20">
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
        users={@users}
        selected_establishment_id={@selected_establishment_id}
        selected_user_id={@selected_user_id}
        impersonating={@impersonating}
      />

      <div class="st-container flex-1 m-4" style="margin-top: 0;">
        <.page_header
          title="� Posições de Atendimento"
          description="Gerencie salas, guichês e mesas de recepção."
          breadcrumb_items={[
            %{label: "Administração", href: "/admin"},
            %{label: "Posições"}
          ]}
        >
          <hr class="my-6 border-white/500 opacity-40 border-dashed" />

          <%= if @selected_establishment_id do %>
            <.action_header title="Lista de Salas">
              <:actions>
                <.search_bar value={@params["search"] || ""} />
                <.link patch={~p"/admin/rooms/new"} class="btn btn-primary h-10 min-h-0">
                  <.icon name="hero-plus" class="mr-2" /> Nova Sala
                </.link>
              </:actions>
            </.action_header>

            <.admin_table id="rooms" rows={@rooms}>
              <:col :let={room} label="Nome">{room.name}</:col>
              <:col :let={room} label="Tipo">
                <span class={"st-badge " <> type_badge_class(room.type)}>
                  {type_label(room.type)}
                </span>
                <%= unless room.is_active do %>
                  <span class="st-badge bg-red-500/30 text-red-200 border border-red-500/50 ml-1">
                    Inativa
                  </span>
                <% end %>
              </:col>
              <:col :let={room} label="Capacidade">{room.capacity_threshold}</:col>
              <:col :let={room} label="Serviços">
                <%= if room.all_services do %>
                  <span class="st-badge bg-purple-500/30 text-purple-200 border border-purple-500/50">
                    Todos
                  </span>
                <% else %>
                  <div class="flex flex-wrap gap-1">
                    <%= for service <- room.services do %>
                      <span class="st-badge bg-blue-500/30 text-blue-200 border border-blue-500/50">
                        {service.name}
                      </span>
                    <% end %>
                    <%= if Enum.empty?(room.services) do %>
                      <span class="text-xs italic text-gray-500">Nenhum</span>
                    <% end %>
                  </div>
                <% end %>
              </:col>
              <:action :let={room}>
                <.link
                  patch={~p"/admin/rooms/#{room}/edit"}
                  class="btn btn-sm btn-ghost btn-square"
                  title="Editar"
                >
                  <.icon name="hero-pencil" class="size-5 text-blue-400" />
                </.link>
                <button
                  id={"delete-room-#{room.id}"}
                  phx-hook="DebounceSubmit"
                  phx-click="confirm_delete"
                  phx-value-id={room.id}
                  class="btn btn-sm btn-ghost btn-square"
                  title="Excluir"
                >
                  <.icon name="hero-trash" class="size-5 text-red-400" />
                </button>
              </:action>
            </.admin_table>
          <% else %>
            <p class="text-yellow-200 bg-yellow-900/40 p-4 rounded border border-yellow-500/50">
              Selecione um estabelecimento no cabeçalho para gerenciar salas.
            </p>
          <% end %>
        </.page_header>
      </div>

      <.modal
        :if={@show_confirm_modal}
        id="confirm-modal"
        show={@show_confirm_modal}
        transparent={true}
        on_cancel={JS.push("cancel_delete")}
      >
        <div class="st-modal-confirm">
          <div class="st-modal-icon-container">
            <.icon name="hero-exclamation-triangle" class="size-12 text-red-500" />
          </div>
          <h3 class="st-modal-title">Excluir Sala?</h3>
          <p class="st-modal-text">
            Tem certeza que deseja excluir esta sala? Esta ação não pode ser desfeita.
          </p>
          <div class="flex justify-center gap-3">
            <button
              phx-click="cancel_delete"
              class="st-modal-btn st-modal-btn-cancel"
            >
              Cancelar
            </button>
            <button
              id="do-delete-room"
              phx-hook="DebounceSubmit"
              phx-click="do_delete"
              class="st-modal-btn st-modal-btn-confirm"
            >
              Excluir
            </button>
          </div>
        </div>
      </.modal>

      <.modal
        :if={@live_action in [:new, :edit]}
        id="room-modal"
        show
        on_cancel={JS.patch(~p"/admin/rooms")}
        transparent={true}
      >
        <.live_component
          module={StarTicketsWeb.Admin.Rooms.FormComponent}
          id={@room.id || :new}
          title={@page_title}
          action={@live_action}
          room={@room}
          establishment_id={@selected_establishment_id}
          patch={~p"/admin/rooms"}
        />
      </.modal>
    </div>
    """
  end

  defp type_label("reception"), do: "Recepção"
  defp type_label("professional"), do: "Profissional"
  defp type_label("both"), do: "Ambos"
  defp type_label(_), do: "Desconhecido"

  defp type_badge_class("reception"),
    do: "bg-emerald-500/30 text-emerald-200 border border-emerald-500/50"

  defp type_badge_class("professional"),
    do: "bg-blue-500/30 text-blue-200 border border-blue-500/50"

  defp type_badge_class("both"),
    do: "bg-purple-500/30 text-purple-200 border border-purple-500/50"

  defp type_badge_class(_), do: "bg-gray-500/30 text-gray-200 border border-gray-500/50"
end
