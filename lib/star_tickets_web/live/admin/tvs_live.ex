defmodule StarTicketsWeb.Admin.TVsLive do
  use StarTicketsWeb, :live_view

  alias StarTicketsWeb.ImpersonationHelpers
  alias StarTickets.Accounts
  alias StarTickets.Accounts.TV
  import StarTicketsWeb.AdminComponents

  @impl true
  def mount(params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    socket =
      socket
      |> assign(impersonation_assigns)
      |> assign(:page_title, "TVs")
      |> assign(:tv, nil)
      |> assign(:params, %{})
      |> assign(show_confirm_modal: false, item_to_delete: nil)

    if socket.assigns.selected_establishment_id do
      tvs = Accounts.list_tvs(socket.assigns.selected_establishment_id)
      {:ok, assign(socket, :tvs, tvs)}
    else
      {:ok, assign(socket, :tvs, [])}
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
      tvs = Accounts.list_tvs(establishment_id, params)
      assign(socket, tvs: tvs, params: params)
    else
      assign(socket, tvs: [], params: params)
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Editar TV")
    |> assign(:tv, Accounts.get_tv!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Nova TV")
    |> assign(:tv, %TV{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "TVs")
    |> assign(:tv, nil)
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    params = Map.put(socket.assigns.params || %{}, "search", search)
    {:noreply, push_patch(socket, to: ~p"/admin/tvs?#{params}")}
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
    tv = Accounts.get_tv!(id)

    # Note: deleting TV also deletes the associated User (handled in context/transaction)
    case Accounts.delete_tv(tv) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:delete, "TV excluída com sucesso!")
         # Re-fetch list
         |> assign_list(socket.assigns.params)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(show_confirm_modal: false, item_to_delete: nil)
         |> put_flash(:error, "Erro ao excluir TV.")}
    end
  end

  @impl true
  def handle_info({StarTicketsWeb.Admin.TVs.FormComponent, {:saved, _tv}}, socket) do
    tvs = Accounts.list_tvs(socket.assigns.selected_establishment_id)
    {:noreply, assign(socket, :tvs, tvs)}
  end

  @impl true
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
          title="📺 Televisões"
          description="Configure os painéis de TV (Chamada de Senhas)."
          breadcrumb_items={[
            %{label: "Administração", href: "/admin"},
            %{label: "TVs"}
          ]}
        >
          <hr class="my-6 border-white/500 opacity-40 border-dashed" />

          <%= if @selected_establishment_id do %>
             <.action_header title="Lista de TVs">
               <:actions>
                 <.search_bar value={@params["search"] || ""} />
                 <.link patch={~p"/admin/tvs/new"} class="btn btn-primary h-10 min-h-0">
                   <.icon name="hero-plus" class="mr-2" /> Nova TV
                 </.link>
               </:actions>
             </.action_header>

             <.admin_table id="tvs" rows={@tvs}>
               <:col :let={tv} label="Nome"><%= tv.name %></:col>
               <:col :let={tv} label="Usuário de Login">
                  <span class="font-mono text-xs bg-black/30 px-2 py-1 rounded text-orange-200">
                    <%= tv.user.username %>
                  </span>
               </:col>
                <:col :let={tv} label="Notícias">
                  <%= if tv.news_enabled do %>
                     <span class="text-xs text-green-300 flex items-center gap-1">
                       <.icon name="hero-check-circle" class="size-4" /> Ativo
                     </span>
                     <div class="text-[10px] text-white/50 truncate max-w-[150px]"><%= tv.news_url %></div>
                  <% else %>
                     <span class="text-xs text-gray-400">Desativado</span>
                  <% end %>
               </:col>
               <:col :let={tv} label="Serviços Visíveis">
                  <%= if tv.all_services do %>
                    <span class="st-badge bg-purple-500/30 text-purple-200 border border-purple-500/50">
                      Todos os Serviços
                    </span>
                  <% else %>
                    <div class="flex flex-wrap gap-1">
                      <%= for service <- tv.services do %>
                        <span class="st-badge bg-blue-500/30 text-blue-200 border border-blue-500/50">
                          <%= service.name %>
                        </span>
                      <% end %>
                      <%= if Enum.empty?(tv.services) do %>
                        <span class="text-xs italic text-gray-500">Nenhum</span>
                      <% end %>
                    </div>
                  <% end %>
               </:col>
               <:action :let={tv}>
                  <.link patch={~p"/admin/tvs/#{tv}/edit"} class="btn btn-sm btn-ghost btn-square" title="Editar">
                    <.icon name="hero-pencil" class="size-5 text-blue-400" />
                  </.link>
                  <button phx-click="confirm_delete" phx-value-id={tv.id} class="btn btn-sm btn-ghost btn-square" title="Excluir">
                    <.icon name="hero-trash" class="size-5 text-red-400" />
                  </button>
               </:action>
             </.admin_table>
          <% else %>
             <p class="text-yellow-200 bg-yellow-900/40 p-4 rounded border border-yellow-500/50">
               Selecione um estabelecimento no cabeçalho para gerenciar TVs.
             </p>
          <% end %>
        </.page_header>
      </div>


      <.modal :if={@show_confirm_modal} id="confirm-modal" show={@show_confirm_modal} transparent={true} on_cancel={JS.push("cancel_delete")}>
        <div class="st-modal-confirm">
          <div class="st-modal-icon-container">
            <.icon name="hero-exclamation-triangle" class="size-12 text-red-500" />
          </div>
          <h3 class="st-modal-title">Excluir TV?</h3>
          <p class="st-modal-text">
            Tem certeza que deseja excluir esta TV? O usuário de login associado também será removido.
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

      <.modal
        :if={@live_action in [:new, :edit]}
        id="tv-modal"
        show
        on_cancel={JS.patch(~p"/admin/tvs")}
        transparent={true}
      >
        <.live_component
          module={StarTicketsWeb.Admin.TVs.FormComponent}
          id={@tv.id || :new}
          title={@page_title}
          action={@live_action}
          tv={@tv}
          establishment_id={@selected_establishment_id}
          patch={~p"/admin/tvs"}
        />
      </.modal>
    </div>
    """
  end
end
