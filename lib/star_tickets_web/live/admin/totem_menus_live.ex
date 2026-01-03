defmodule StarTicketsWeb.Admin.TotemMenusLive do
  use StarTicketsWeb, :live_view

  alias StarTicketsWeb.ImpersonationHelpers
  alias StarTickets.Accounts
  alias StarTickets.Accounts.TotemMenu

  def mount(%{"establishment_id" => establishment_id}, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    establishment = Accounts.get_establishment!(establishment_id)
    menus = Accounts.list_totem_menus(establishment_id)

    # Organize menus into a tree structure?
    # Or just flat list and render recursively?
    # For now, load flat list.

    services = Accounts.list_establishment_services(establishment_id)

    socket =
      socket
      |> assign(impersonation_assigns)
      |> assign(:establishment, establishment)
      |> assign(:menus, menus)
      |> assign(:services, services)
      |> assign(:selected_node, nil)
      |> assign(:form, nil)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-20">
      <.app_header
        title="Totem"
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

      <div class="st-container flex-1 m-4 overflow-hidden flex flex-col" style="margin-top: 0;">
        <div class="mb-6">
          <div class="st-card st-acrylic px-4 py-2 inline-block rounded-full">
            <.breadcrumb items={[
              %{label: "Administração", href: "/admin"},
              %{label: "Totens", href: "/admin/totems"},
              %{label: "Menu"}
            ]} />
          </div>
        </div>
        <div class="flex flex-1 overflow-hidden bg-black/20 backdrop-blur-md border border-white/10 rounded-xl">
          <!-- Sidebar: Tree View -->
          <div class="w-1/3 border-r border-white/10 bg-white/5 overflow-y-auto p-4">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h2 class="text-lg font-bold text-white tracking-tight">Menu de Navegação</h2>
                <p class="text-xs text-white/50 font-medium">{@establishment.name}</p>
              </div>
              <button
                id="new-root-btn"
                phx-hook="DebounceSubmit"
                phx-click="new_root"
                class="btn btn-xs btn-primary"
              >
                + Raiz
              </button>
            </div>
            <hr class="my-4 border-white/10 border-dashed" />

            <div class="space-y-1">
              <%= for menu <- Enum.filter(@menus, &is_nil(&1.parent_id)) do %>
                <.menu_node menu={menu} menus={@menus} selected_node={@selected_node} />
              <% end %>
            </div>
          </div>
          
    <!-- Main: Editor -->
          <div class="flex-1 overflow-y-auto p-8 relative">
            <%= if @selected_node do %>
              <div class="max-w-2xl mx-auto">
                <div class="flex items-center justify-between mb-6">
                  <h2 class="text-2xl font-bold text-white">
                    {if @selected_node.id, do: "Editar Nó", else: "Novo Nó"}
                  </h2>
                  <%= if @selected_node.id do %>
                    <button
                      id={"delete-node-#{@selected_node.id}"}
                      phx-hook="DebounceSubmit"
                      phx-click="delete_node"
                      phx-value-id={@selected_node.id}
                      data-confirm="Tem certeza? Isso apagará todos os filhos!"
                      class="btn btn-error btn-sm"
                    >
                      Excluir
                    </button>
                  <% end %>
                </div>

                <.form
                  for={@form}
                  phx-change="validate"
                  phx-submit="save"
                  class="space-y-6"
                  phx-debounce="300"
                >
                  <div class="grid grid-cols-1 gap-6">
                    <div>
                      <label class="label text-white/90 font-medium mb-2">
                        Nome (Texto no Botão via Totem)
                      </label>
                      <.input
                        field={@form[:name]}
                        placeholder="Ex: Atendimento Prioritário"
                        class="input-bordered bg-white/5 border-white/10 text-white placeholder-white/30 w-full h-12 text-lg px-4 focus:bg-white/10 focus:border-orange-500/50 focus:outline-none transition-all"
                      />
                    </div>

                    <div>
                      <label class="label text-white/90 font-medium mb-2">
                        Ícone (FontAwesome Class)
                      </label>
                      <.input
                        field={@form[:icon_class]}
                        placeholder="Ex: fa-solid fa-user-doctor"
                        class="input-bordered bg-white/5 border-white/10 text-white placeholder-white/30 w-full h-12 text-lg px-4 focus:bg-white/10 focus:border-orange-500/50 focus:outline-none transition-all"
                      />
                    </div>

                    <div>
                      <label class="label text-white/90 font-medium mb-2">
                        Descrição (Exibido abaixo do nome)
                      </label>
                      <.input
                        field={@form[:description]}
                        type="textarea"
                        placeholder="Ex: Selecione para atendimento preferencial..."
                        class="textarea-bordered bg-white/5 border-white/10 text-white placeholder-white/30 w-full text-lg px-4 py-3 h-24 focus:bg-white/10 focus:border-blue-500/50 transition-all"
                      />
                    </div>

                    <div class="flex items-center gap-3 p-4 rounded-lg bg-white/5 border border-white/10">
                      <.input
                        field={@form[:is_taggable]}
                        type="checkbox"
                        class="checkbox checkbox-primary"
                      />
                      <div>
                        <label class="label text-white/90 font-medium cursor-pointer">
                          🏷️ Usar como Filtro
                        </label>
                        <p class="text-white/50 text-sm">
                          Marque para exibir este item como opção de filtro na tela da recepção
                        </p>
                      </div>
                    </div>
                  </div>

                  <%= if @selected_node.id do %>
                    <div class="flex items-center gap-4 my-8">
                      <hr class="flex-1 border-white/10 border-dashed" />
                      <span class="text-white/50 text-sm font-medium uppercase tracking-wider">
                        Serviços Vinculados
                      </span>
                      <hr class="flex-1 border-white/10 border-dashed" />
                    </div>
                    <p class="text-sm text-white/60 mb-4">
                      Se este nó for selecionado, quais serviços estarão disponíveis?
                    </p>

                    <div class="bg-black/20 rounded p-4 max-h-80 overflow-y-auto border border-white/10 space-y-4">
                      <!-- Service Rows -->
                      <%= for service <- @services do %>
                        <% service_state = get_service_state(@services_state, service.id) %>
                        <div class="p-3 rounded border border-white/10 bg-white/5">
                          <label class="flex items-center gap-3 cursor-pointer group">
                            <input
                              type="checkbox"
                              name={"services[#{service.id}][enabled]"}
                              value="true"
                              checked={service_state["enabled"] == "true"}
                              class="checkbox checkbox-sm checkbox-primary border-white/30"
                            />
                            <span class="text-white font-medium group-hover:text-orange-400 transition-colors">
                              {service.name}
                            </span>
                          </label>
                          <div class="mt-3 grid grid-cols-2 gap-3 pl-8">
                            <input
                              type="text"
                              name={"services[#{service.id}][icon_class]"}
                              placeholder="Ícone (ex: fa-solid fa-vial)"
                              value={service_state["icon_class"]}
                              class="input input-sm input-bordered bg-white/5 border-white/10 text-white placeholder-white/30 w-full focus:outline-none focus:border-orange-500/50 transition-colors"
                            />
                            <input
                              type="text"
                              name={"services[#{service.id}][description]"}
                              placeholder="Descrição breve..."
                              value={service_state["description"]}
                              class="input input-sm input-bordered bg-white/5 border-white/10 text-white placeholder-white/30 w-full focus:outline-none focus:border-orange-500/50 transition-colors"
                            />
                          </div>
                        </div>
                      <% end %>
                      <%= if Enum.empty?(@services) do %>
                        <div class="text-white/40 text-center py-4">Nenhum serviço cadastrado.</div>
                      <% end %>
                    </div>
                  <% end %>
                  
    <!-- Display Parent Info -->
                  <%= if @selected_node.parent_id do %>
                    <div class="text-sm text-white/60 mt-6">
                      Pai: {get_node_name(@menus, @selected_node.parent_id)}
                    </div>
                  <% else %>
                    <div class="text-sm text-white/60 mt-6">Nó Raiz</div>
                  <% end %>

                  <div class="flex justify-end gap-2 mt-6">
                    <button
                      type="button"
                      phx-click="cancel"
                      class="btn btn-ghost text-white/70 hover:text-white"
                    >
                      Cancelar
                    </button>
                    <button type="submit" class="btn btn-primary">Salvar</button>
                  </div>
                </.form>

                <%= if @selected_node.id do %>
                  <div class="flex items-center gap-4 my-8">
                    <hr class="flex-1 border-white/10 border-dashed" />
                    <span class="text-white/50 text-sm font-medium uppercase tracking-wider">
                      Ações
                    </span>
                    <hr class="flex-1 border-white/10 border-dashed" />
                  </div>

                  <div class="grid grid-cols-2 gap-4">
                    <div
                      id={"add-child-#{@selected_node.id}"}
                      phx-hook="DebounceSubmit"
                      class="p-4 rounded border border-white/10 bg-white/5 hover:bg-white/10 hover:border-orange-500/50 transition cursor-pointer"
                      phx-click="add_child"
                      phx-value-parent_id={@selected_node.id}
                    >
                      <div class="font-bold mb-1 text-white">+ Adicionar Sub-Item</div>
                      <div class="text-xs text-white/60">
                        Criar novo item dentro de "{@selected_node.name}"
                      </div>
                    </div>
                    <div
                      id={"duplicate-tree-#{@selected_node.id}"}
                      phx-hook="DebounceSubmit"
                      class="p-4 rounded border border-white/10 bg-white/5 hover:bg-white/10 hover:border-orange-500/50 transition cursor-pointer"
                      phx-click="duplicate_tree"
                      phx-value-id={@selected_node.id}
                    >
                      <div class="font-bold mb-1 text-white">📋 Duplicar Estrutura</div>
                      <div class="text-xs text-white/60">
                        Copiar "{@selected_node.name}" e todos seus filhos como nova raiz
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="flex h-full items-center justify-center text-white/20">
                Selecione um item à esquerda ou crie uma raiz.
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Recursive Component for Tree
  def menu_node(assigns) do
    ~H"""
    <div class="pl-4 border-l border-white/5 ml-2">
      <div class={"group flex items-center gap-2 py-1.5 px-3 rounded-lg transition-all duration-200 " <> if(@selected_node && @selected_node.id == @menu.id, do: "bg-blue-500/10 border border-blue-500/20 text-blue-200 shadow-lg shadow-blue-500/5 backdrop-blur", else: "text-white/70 hover:bg-white/5 hover:text-white")}>
        <!-- Row Content (Clickable) -->
        <div
          class="flex-1 flex items-center gap-2 cursor-pointer"
          phx-click="edit_node"
          phx-value-id={@menu.id}
        >
          <div class="w-2 h-2 rounded-full bg-orange-500"></div>
          <span class="text-sm font-medium">{@menu.name}</span>
          <%= if @menu.is_taggable do %>
            <span
              class="text-[10px] bg-orange-500/20 text-orange-300 px-1.5 py-0.5 rounded"
              title="Filtro"
            >
              🏷️
            </span>
          <% end %>
        </div>
        
    <!-- Reorder Controls (Only visible on hover or selected) -->
        <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            phx-click="move_node"
            phx-value-id={@menu.id}
            phx-value-dir="up"
            class="p-1 hover:bg-white/20 rounded text-white/50 hover:text-white"
            title="Mover para cima"
          >
            <.icon name="hero-chevron-up" class="w-3 h-3" />
          </button>
          <button
            phx-click="move_node"
            phx-value-id={@menu.id}
            phx-value-dir="down"
            class="p-1 hover:bg-white/20 rounded text-white/50 hover:text-white"
            title="Mover para baixo"
          >
            <.icon name="hero-chevron-down" class="w-3 h-3" />
          </button>
        </div>
      </div>
      
    <!-- Render Children -->
      <% children = Enum.filter(@menus, &(&1.parent_id == @menu.id)) %>
      <%= if Enum.any?(children) do %>
        <div class="mt-1">
          <%= for child <- children do %>
            <.menu_node menu={child} menus={@menus} selected_node={@selected_node} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("new_root", _, socket) do
    changeset =
      TotemMenu.changeset(%TotemMenu{}, %{
        establishment_id: socket.assigns.establishment.id,
        type: :tag
      })

    {:noreply,
     socket
     |> assign(selected_node: %TotemMenu{}, form: to_form(changeset))
     |> assign(:services_state, %{})}
  end

  def handle_event("edit_node", %{"id" => id}, socket) do
    menu = Enum.find(socket.assigns.menus, &(&1.id == String.to_integer(id)))
    changeset = TotemMenu.changeset(menu, %{})

    # Initialize services state from existing node data
    services_state =
      if menu.totem_menu_services do
        Enum.into(menu.totem_menu_services, %{}, fn link ->
          {to_string(link.service_id),
           %{
             "enabled" => "true",
             "icon_class" => link.icon_class,
             "description" => link.description
           }}
        end)
      else
        %{}
      end

    {:noreply,
     socket
     |> assign(selected_node: menu, form: to_form(changeset))
     |> assign(:services_state, services_state)}
  end

  def handle_event("validate", params, socket) do
    menu_params = params["totem_menu"] || %{}
    services_params = params["services"] || %{}

    # We trust services_params as the source of truth for the UI state
    # (Since all inputs are present in the form, even unchecked boxes imply absence of 'enabled')

    changeset =
      if socket.assigns.selected_node.id do
        TotemMenu.changeset(socket.assigns.selected_node, menu_params)
      else
        %TotemMenu{}
        |> TotemMenu.changeset(
          Map.merge(menu_params, %{"establishment_id" => socket.assigns.establishment.id})
        )
      end

    {:noreply,
     socket
     |> assign(form: to_form(changeset, action: :validate))
     |> assign(:services_state, services_params)}
  end

  def handle_event("add_child", %{"parent_id" => parent_id}, socket) do
    parent_id = String.to_integer(parent_id)
    new_node = %TotemMenu{parent_id: parent_id}

    changeset =
      TotemMenu.changeset(new_node, %{
        establishment_id: socket.assigns.establishment.id,
        type: :tag
      })

    {:noreply,
     socket
     |> assign(selected_node: new_node, form: to_form(changeset))
     |> assign(:services_state, %{})}
  end

  def handle_event("delete_node", %{"id" => id}, socket) do
    menu = Enum.find(socket.assigns.menus, &(&1.id == String.to_integer(id)))
    Accounts.delete_totem_menu(menu)

    menus = Accounts.list_totem_menus(socket.assigns.establishment.id)

    {:noreply,
     socket
     |> assign(:menus, menus)
     |> assign(:selected_node, nil)
     |> put_flash(:info, "Nó excluído.")}
  end

  def handle_event("save", params, socket) do
    menu_params = params["totem_menu"] || %{}
    services_params = params["services"] || %{}

    # Add parent_id if it exists on current node
    menu_params =
      if Map.get(socket.assigns.selected_node, :parent_id) do
        Map.put(menu_params, "parent_id", socket.assigns.selected_node.parent_id)
      else
        menu_params
      end

    # Process services data if present
    # We use services_params which comes from the form submission (reliable)
    services_data =
      services_params
      |> Enum.filter(fn {_id, p} -> p["enabled"] == "true" end)
      |> Enum.map(fn {id, p} ->
        %{"service_id" => id, "description" => p["description"], "icon_class" => p["icon_class"]}
      end)

    menu_params = Map.put(menu_params, "services_data", services_data)

    case save_menu(socket.assigns.selected_node, menu_params, socket.assigns.establishment.id) do
      {:ok, _menu} ->
        menus = Accounts.list_totem_menus(socket.assigns.establishment.id)

        {:noreply,
         socket
         |> assign(:menus, menus)
         |> put_flash(:info, "Salvo com sucesso!")
         |> assign(:selected_node, nil)
         |> assign(:services_state, %{})}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("move_node", %{"id" => id, "dir" => dir}, socket) do
    direction = String.to_existing_atom(dir)

    case Accounts.move_totem_menu(id, direction) do
      {:ok, _} ->
        menus = Accounts.list_totem_menus(socket.assigns.establishment.id)
        {:noreply, assign(socket, :menus, menus)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("duplicate_tree", %{"id" => id}, socket) do
    case Accounts.duplicate_totem_menu_tree(id, nil) do
      {:ok, _new_menu} ->
        menus = Accounts.list_totem_menus(socket.assigns.establishment.id)

        {:noreply,
         socket
         |> assign(:menus, menus)
         |> assign(:selected_node, nil)
         |> put_flash(:info, "Estrutura duplicada com sucesso!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao duplicar estrutura.")}
    end
  end

  defp save_menu(node, params, estab_id) do
    if node.id do
      Accounts.update_totem_menu(node, params)
    else
      params = Map.put(params, "establishment_id", estab_id)
      # If parent_id is in params (from handle_event logic), it's respected.
      Accounts.create_totem_menu(params)
    end
  end

  defp get_node_name(menus, id) do
    case Enum.find(menus, &(&1.id == id)) do
      nil -> "Desconhecido"
      menu -> menu.name
    end
  end

  defp get_service_state(services_state, service_id) do
    services_state[to_string(service_id)] || %{}
  end
end
