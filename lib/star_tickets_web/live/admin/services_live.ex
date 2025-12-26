defmodule StarTicketsWeb.Admin.ServicesLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Accounts
  alias StarTickets.Accounts.Service
  import StarTicketsWeb.AdminComponents

  alias StarTicketsWeb.ImpersonationHelpers

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

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
      # Should not happen for admin
      {:ok, socket}
    end
  end

  def handle_params(params, _url, socket) do
    socket =
      socket
      |> apply_action(socket.assigns.live_action, params)
      |> assign_list(params)

    {:noreply, socket}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Editar Serviço")
    |> assign(:service, Accounts.get_service!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Novo Serviço")
    |> assign(:service, %Service{client_id: socket.assigns.client_id})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Serviços")
    |> assign(:service, nil)
  end

  defp assign_list(socket, params) do
    page = String.to_integer(params["page"] || "1")
    search_term = params["search"] || ""

    filter_params = %{
      "page" => "#{page}",
      "per_page" => "10",
      "search" => search_term,
      "client_id" => socket.assigns.client_id
    }

    services = Accounts.list_services(filter_params)
    total_count = Accounts.count_services(filter_params)
    total_pages = ceil(total_count / 10)

    assign(socket,
      services: services,
      total_pages: total_pages,
      page: page,
      search_term: search_term
    )
  end

  def handle_event("delete", %{"id" => id}, socket) do
    service = Accounts.get_service!(id)
    {:noreply, assign(socket, show_confirm_modal: true, item_to_delete: service)}
  end

  def handle_event("confirm_delete", _params, socket) do
    service = socket.assigns.item_to_delete

    case Accounts.delete_service(service) do
      {:ok, _} ->
        filter_params = %{
          "page" => "#{socket.assigns.page}",
          "per_page" => "10",
          "search" => socket.assigns.search_term,
          "client_id" => socket.assigns.client_id
        }

        services = Accounts.list_services(filter_params)

        {:noreply,
         socket
         |> assign(services: services, show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:delete, "Serviço excluído com sucesso.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao excluir serviço.")}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_confirm_modal: false, item_to_delete: nil)}
  end

  def handle_event("search", %{"search" => search_term}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/services?search=#{search_term}")}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    params = %{search: socket.assigns.search_term, page: page}
    {:noreply, push_patch(socket, to: ~p"/admin/services?#{params}")}
  end

  def handle_info({StarTicketsWeb.Admin.Services.FormComponent, {:saved, _service, msg}}, socket) do
    {:noreply,
     socket
     |> put_flash(:success, msg)
     |> push_patch(to: ~p"/admin/services")}
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
        users={@users}
        selected_establishment_id={@selected_establishment_id}
        selected_user_id={@selected_user_id}
        impersonating={@impersonating}
      />

      <div class="st-container flex-1 m-4">
        <.page_header
          title="🔧 Serviços"
          description="Gerencie os serviços oferecidos."
          breadcrumb_items={[
            %{label: "Administração", href: "/admin"},
            %{label: "Serviços"}
          ]}
        >
        <hr class="my-6 border-white/500 opacity-40 border-dashed" />

        <.action_header title="Lista de Serviços">
            <:actions>
              <.search_bar value={@search_term} />
              <.link patch={~p"/admin/services/new"} class="btn btn-primary h-10 min-h-0">
                <.icon name="hero-plus" class="mr-2" /> Novo
              </.link>
            </:actions>
        </.action_header>

        <.admin_table id="services" rows={@services}>
          <:col :let={service} label="Nome do Serviço">{service.name}</:col>
          <:col :let={service} label="Duração">{service.duration} minutos</:col>
          <:action :let={service}>
            <.link patch={~p"/admin/services/#{service}/edit"} class="btn btn-sm btn-ghost btn-square" title="Editar">
              <.icon name="hero-pencil-square" class="size-5 text-blue-400" />
            </.link>
            <button
              phx-click="delete"
              phx-value-id={service.id}
              class="btn btn-sm btn-ghost btn-square"
              title="Excluir"
            >
              <.icon name="hero-trash" class="size-5 text-red-400" />
            </button>
          </:action>
        </.admin_table>

        <.pagination page={@page} total_pages={@total_pages} />
        </.page_header>
      </div>

      <.app_footer />

      <%= if @live_action in [:new, :edit] do %>
        <.modal id="service-modal" show on_cancel={JS.patch(~p"/admin/services")} transparent={true}>
          <.live_component
            module={StarTicketsWeb.Admin.Services.FormComponent}
            id={@service.id || :new}
            title={@page_title}
            action={@live_action}
            service={@service}
            current_user_scope={@current_scope}
            patch={~p"/admin/services"}
          />
        </.modal>
      <% end %>

      <.confirm_modal
        show={@show_confirm_modal}
        title="Excluir Serviço?"
        message="Tem certeza que deseja excluir este serviço? Esta ação não pode ser desfeita."
        confirm_label="Sim, excluir"
        cancel_label="Cancelar"
        on_confirm="confirm_delete"
        on_cancel="cancel_delete"
      />
    </div>
    """
  end
end
