defmodule StarTicketsWeb.Admin.FormsLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Forms
  alias StarTickets.Forms.FormTemplate
  import StarTicketsWeb.AdminComponents

  alias StarTicketsWeb.ImpersonationHelpers

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    socket =
      socket
      |> assign(impersonation_assigns)
      |> assign(:show_confirm_modal, false)
      |> assign(:item_to_delete, nil)

    if scope = socket.assigns[:current_scope] do
      client = StarTickets.Accounts.get_client!(scope.user.client_id)

      {:ok,
       assign(socket,
         client_id: client.id,
         client_name: client.name
       )}
    else
      {:ok, assign(socket, client_id: nil)}
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

    filter_params = %{
      "page" => "#{page}",
      "page_size" => "10",
      "search" => search_term,
      "client_id" => socket.assigns.client_id
    }

    templates = Forms.list_templates(filter_params)
    total_count = Forms.count_templates(search_term, socket.assigns.client_id)
    total_pages = ceil(total_count / 10)

    assign(socket,
      templates: templates,
      total_pages: total_pages,
      page: page,
      search_term: search_term
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Editar Modelo")
    |> assign(:form_template, Forms.get_template!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Novo Modelo")
    |> assign(:form_template, %FormTemplate{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Formulários")
    |> assign(:form_template, nil)
  end

  def handle_info({StarTicketsWeb.Admin.Forms.FormComponent, {:saved, _template, msg}}, socket) do
    {:noreply,
     socket
     |> put_flash(:success, msg)
     |> push_patch(to: ~p"/admin/forms")}
  end

  def handle_event("search", %{"search" => search_term}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/forms?search=#{search_term}")}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    params = %{search: socket.assigns.search_term, page: page}
    {:noreply, push_patch(socket, to: ~p"/admin/forms?#{params}")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    template = Forms.get_template!(id)
    {:noreply, assign(socket, show_confirm_modal: true, item_to_delete: template)}
  end

  def handle_event("confirm_delete", _params, socket) do
    template = socket.assigns.item_to_delete

    case Forms.delete_template(template) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:info, "Formulário excluído com sucesso")
         |> push_patch(to: ~p"/admin/forms")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:error, "Erro ao excluir formulário")}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_confirm_modal: false, item_to_delete: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col" style="padding-top: 80px;">
      <.flash kind={:info} title="Informação" flash={@flash} />
      <.flash kind={:success} title="Sucesso" flash={@flash} />
      <.flash kind={:warning} title="Atenção" flash={@flash} />
      <.flash kind={:error} title="Erro" flash={@flash} />

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
          title="📝 Formulários"
          description="Gerencie os modelos de formulários de atendimento."
          breadcrumb_items={[
            %{label: "Administração", href: "/admin"},
            %{label: "Formulários"}
          ]}
        >
          <hr class="my-6 border-white/500 opacity-40 border-dashed" />

          <.action_header title="Lista de Modelos">
            <:actions>
              <.search_bar value={@search_term} />
              <.link patch={~p"/admin/forms/new"} class="btn btn-primary h-10 min-h-0">
                <.icon name="hero-plus" class="mr-2" /> Novo
              </.link>
            </:actions>
          </.action_header>

          <.admin_table id="forms" rows={@templates}>
            <:col :let={template} label="Nome">{template.name}</:col>
            <:col :let={template} label="Descrição">{template.description || "-"}</:col>
            <:col :let={template} label="Campos">
              <span class="st-badge bg-blue-500/20 text-blue-200 border border-blue-500/50">
                {length(template.form_fields || [])} campos
              </span>
            </:col>

            <:action :let={template}>
               <.link navigate={~p"/admin/forms/#{template}/builder"} class="btn btn-sm btn-ghost btn-square" title="Construtor de Campos">
                  <.icon name="hero-puzzle-piece" class="size-5 text-yellow-400" />
               </.link>

              <.link patch={~p"/admin/forms/#{template}/edit"} class="btn btn-sm btn-ghost btn-square" title="Editar Metadados">
                <.icon name="hero-pencil-square" class="size-5 text-blue-400" />
              </.link>
              <button
                phx-click="delete"
                phx-value-id={template.id}
                class="btn btn-sm btn-ghost btn-square"
                title="Excluir"
              >
                <.icon name="hero-trash" class="size-5 text-red-400" />
              </button>
            </:action>
          </.admin_table>

          <.pagination page={@page} total_pages={@total_pages} />
        </.page_header>

        <.confirm_modal
          show={@show_confirm_modal}
          id="confirm-modal"
          title="Excluir Formulário?"
          message={if @item_to_delete, do: "Deseja excluir '#{@item_to_delete.name}'? Isso removerá todos os campos associados.", else: ""}
          confirm_label="Excluir"
          cancel_label="Cancelar"
          on_confirm="confirm_delete"
          on_cancel="cancel_delete"
        />
      </div>

      <.app_footer />

      <%= if @live_action in [:new, :edit] do %>
        <.modal id="form-template-modal" show on_cancel={JS.patch(~p"/admin/forms")} transparent={true}>
          <.live_component
            module={StarTicketsWeb.Admin.Forms.FormComponent}
            id={@form_template.id || :new}
            title={@page_title}
            action={@live_action}
            form_template={@form_template}
            patch={~p"/admin/forms"}
            current_user_scope={@current_scope}
          />
        </.modal>
      <% end %>
    </div>
    """
  end
end
