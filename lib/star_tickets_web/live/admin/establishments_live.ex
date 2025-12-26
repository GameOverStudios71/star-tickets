defmodule StarTicketsWeb.Admin.EstablishmentsLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Accounts
  alias StarTickets.Accounts.Establishment
  import StarTicketsWeb.AdminComponents

  alias StarTicketsWeb.ImpersonationHelpers

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    # Rename establishments to header_establishments to avoid conflict with table data
    impersonation_assigns =
      Map.put(impersonation_assigns, :header_establishments, impersonation_assigns.establishments)

    socket = assign(socket, impersonation_assigns)

    if scope = socket.assigns[:current_scope] do
      client = Accounts.get_client!(scope.user.client_id)

      {:ok,
       assign(socket,
         client_name: client.name,
         client_id: client.id,
         show_confirm_modal: false,
         item_to_delete: nil
       )}
    else
      {:ok,
       assign(socket,
         client_name: "empresa",
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

    # Filter by user's client_id scope if present
    filter_params = %{
      "page" => "#{page}",
      "page_size" => "10",
      "search" => search_term,
      "client_id" => socket.assigns.client_id
    }

    # If scoped to client (manager/admin), ensure we only list their establishments
    # This is handled by list_establishments if client_id is passed
    # Note: Currently list_establishments ignores client_id filter in Accounts context,
    # but we pass it for future compatibility.
    establishments = Accounts.list_establishments(filter_params)

    # Need count for pagination
    # Use existing count_establishments which accepts search_term string
    total_count = Accounts.count_establishments(search_term)
    total_pages = ceil(total_count / 10)

    assign(socket,
      establishments: establishments,
      total_pages: total_pages,
      page: page,
      search_term: search_term
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Editar Estabelecimento")
    |> assign(:establishment, Accounts.get_establishment!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Novo Estabelecimento")
    |> assign(:establishment, %Establishment{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Estabelecimentos")
    |> assign(:establishment, nil)
  end

  def handle_info(
        {StarTicketsWeb.Admin.Establishments.FormComponent, {:saved, _establishment, msg}},
        socket
      ) do
    {:noreply,
     socket
     |> put_flash(:success, msg)
     |> push_patch(to: ~p"/admin/establishments")}
  end

  def handle_event("search", %{"search" => search_term}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/establishments?search=#{search_term}")}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    params = %{search: socket.assigns.search_term, page: page}
    {:noreply, push_patch(socket, to: ~p"/admin/establishments?#{params}")}
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
        establishment_name={if length(@header_establishments) == 0, do: @establishment_name}
        establishments={@header_establishments}
        users={@users}
        selected_establishment_id={@selected_establishment_id}
        selected_user_id={@selected_user_id}
        impersonating={@impersonating}
      />

      <div class="st-container flex-1 m-4">
        <.page_header
          title="🏢 Estabelecimentos"
          description="Gerencie os estabelecimentos da sua empresa."
          breadcrumb_items={[
            %{label: "Administração", href: "/admin"},
            %{label: "Estabelecimentos"}
          ]}
        >
          <hr class="my-6 border-white/500 opacity-40 border-dashed" />

          <.action_header title="Lista de Estabelecimentos">
            <:actions>
              <.search_bar value={@search_term} />
              <.link patch={~p"/admin/establishments/new"} class="btn btn-primary h-10 min-h-0">
                <.icon name="hero-plus" class="mr-2" /> Novo
              </.link>
            </:actions>
          </.action_header>

          <.admin_table id="establishments" rows={@establishments}>
            <:col :let={establishment} label="Nome">{establishment.name}</:col>
            <:col :let={establishment} label="Código">
            <span class="st-badge font-mono bg-yellow-500/30 text-yellow-200 border border-yellow-500/50">{establishment.code}</span>
          </:col>
          <:col :let={establishment} label="Endereço">{establishment.address || "-"}</:col>
          <:col :let={establishment} label="Telefone">{establishment.phone || "-"}</:col>
          <:col :let={establishment} label="Status">
            <span class={"st-badge #{if establishment.is_active, do: "bg-green-500/30 text-green-200 border border-green-500/50", else: "bg-red-500/30 text-red-200 border border-red-500/50"}"}>
              {if establishment.is_active, do: "Ativo", else: "Inativo"}
            </span>
          </:col>
            <:action :let={establishment}>
              <.link patch={~p"/admin/establishments/#{establishment}/edit"} class="btn btn-sm btn-ghost btn-square" title="Editar">
                <.icon name="hero-pencil-square" class="size-5 text-blue-400" />
              </.link>
              <button
                phx-click="confirm_delete"
                phx-value-id={establishment.id}
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
            <h3 class="st-modal-title">Excluir Estabelecimento?</h3>
            <p class="st-modal-text">
              Tem certeza que deseja excluir este estabelecimento? Esta ação não pode ser desfeita.
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


      <.modal :if={@live_action in [:new, :edit]} id="establishment-modal" transparent={true} show on_cancel={JS.patch(~p"/admin/establishments")}>
        <.live_component
          module={StarTicketsWeb.Admin.Establishments.FormComponent}
          id={@establishment.id || :new}
          title={@page_title}
          action={@live_action}
          establishment={@establishment}
          patch={~p"/admin/establishments"}
          client_name={@client_name}
          client_id={@client_id}
        />
      </.modal>
    </div>
    """
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_confirm_modal: true, item_to_delete: id)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_confirm_modal: false, item_to_delete: nil)}
  end

  def handle_event("do_delete", _params, socket) do
    id = socket.assigns.item_to_delete
    establishment = Accounts.get_establishment!(id)

    case Accounts.delete_establishment(establishment) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:delete, "Estabelecimento excluído com sucesso!")
         |> push_navigate(to: ~p"/admin/establishments")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:error, "Erro ao excluir estabelecimento.")}
    end
  end
end
