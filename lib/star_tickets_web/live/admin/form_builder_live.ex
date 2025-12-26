defmodule StarTicketsWeb.Admin.FormBuilderLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Forms
  alias StarTickets.Forms.FormTemplate
  alias StarTickets.Forms.FormField
  import StarTicketsWeb.AdminComponents
  alias StarTicketsWeb.ImpersonationHelpers

  def mount(%{"id" => id}, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    template = Forms.get_template!(id)
    fields = Forms.list_fields(template.id)

    {:ok,
     socket
     |> assign(impersonation_assigns)
     |> assign(:template, template)
     |> assign(:fields, fields)
     |> assign(:active_field, nil)
     |> assign(:new_field_type, nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-[80px]">
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
          title={"Construtor: #{@template.name}"}
          description="Adicione e configure os campos do formulário."
          breadcrumb_items={[
            %{label: "Admin", href: "/admin"},
            %{label: "Formulários", href: "/admin/forms"},
            %{label: @template.name}
          ]}
        >
          <:actions>
             <.link navigate={~p"/admin/forms"} class="btn btn-ghost text-white">Voltar</.link>
          </:actions>
        </.page_header>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-6">
          <!-- Canvas (Field List) -->
          <div class="lg:col-span-2 space-y-4">
             <div class="st-acrylic p-6 rounded-xl min-h-[500px]">
                <h3 class="text-white font-semibold mb-4 flex items-center gap-2">
                   <.icon name="hero-document-text" class="size-5" />
                   Preview do Formulário
                </h3>

                <div class="space-y-4">
                  <%= if @fields == [] do %>
                    <div class="text-center py-10 text-gray-400 border-2 border-dashed border-gray-600 rounded-lg">
                      <p>Nenhum campo adicionado ainda.</p>
                      <p class="text-sm">Selecione um tipo ao lado para começar.</p>
                    </div>
                  <% end %>

                  <%= for field <- @fields do %>
                    <div class="bg-black/20 p-4 rounded border border-white/5 hover:border-blue-500/50 transition-colors group relative">
                       <div class="flex justify-between items-start mb-2">
                          <label class="text-white font-medium flex items-center gap-2">
                             {field.label}
                             <span :if={field.required} class="text-red-400 text-xs">*</span>
                          </label>
                          <div class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity text-white items-center">
                             <button phx-click="move_field" phx-value-id={field.id} phx-value-direction="up" class="p-1 hover:text-yellow-400" title="Mover para Cima"><.icon name="hero-arrow-up" class="size-4" /></button>
                             <button phx-click="move_field" phx-value-id={field.id} phx-value-direction="down" class="p-1 hover:text-yellow-400" title="Mover para Baixo"><.icon name="hero-arrow-down" class="size-4" /></button>
                             <div class="w-px h-4 bg-white/20 mx-1"></div>
                             <button phx-click="edit_field" phx-value-id={field.id} class="p-1 hover:text-blue-400" title="Editar"><.icon name="hero-pencil" class="size-4" /></button>
                             <button phx-click="delete_field" phx-value-id={field.id} class="p-1 hover:text-red-400" title="Excluir"><.icon name="hero-trash" class="size-4" /></button>
                          </div>
                       </div>

                       <!-- Field Preview -->
                       <div class="opacity-80 pointer-events-none">
                         <%= case field.type do %>
                           <% "text" -> %> <input type="text" class="input input-sm w-full bg-white/5" placeholder={field.placeholder || "Texto curto..."} disabled />
                           <% "number" -> %> <input type="number" class="input input-sm w-full bg-white/5" placeholder={field.placeholder || "123..."} disabled />
                           <% "textarea" -> %> <textarea class="textarea textarea-sm w-full bg-white/5" placeholder={field.placeholder || "Texto longo..."} disabled></textarea>
                           <% "checkbox" -> %>
                              <%= if field.options["items"] && field.options["items"] != [] do %>
                                <div class="grid grid-cols-2 gap-2">
                                  <%= for opt <- field.options["items"] do %>
                                    <label class="flex items-center gap-2"><input type="checkbox" class="checkbox checkbox-xs" /> <span class="text-sm text-gray-200">{opt["label"]}</span></label>
                                  <% end %>
                                </div>
                              <% else %>
                                <div class="flex items-center gap-2"><input type="checkbox" class="checkbox checkbox-sm" disabled /> <span class="text-gray-200">Sim/Não</span></div>
                              <% end %>
                           <% "radio" -> %>
                              <div class="flex gap-4 flex-wrap">
                                  <%= for opt <- (field.options["items"] || [%{"label" => "Opção 1"}]) do %>
                                    <label class="flex items-center gap-2"><input type="radio" class="radio radio-xs" disabled /> <span class="text-sm text-gray-200">{opt["label"]}</span></label>
                                  <% end %>
                              </div>
                           <% "select" -> %>
                              <select class="select select-sm w-full bg-white/5" disabled>
                                  <option>Selecione...</option>
                                  <%= for opt <- (field.options["items"] || []) do %>
                                    <option>{opt["label"]}</option>
                                  <% end %>
                              </select>
                           <% "file" -> %> <div class="border border-dashed p-2 text-center text-xs text-gray-300">Upload de Arquivo</div>
                           <% _ -> %> <p class="text-red-400">Tipo desconhecido</p>
                         <% end %>
                       </div>
                    </div>
                  <% end %>
                </div>
             </div>
          </div>

          <!-- Sidebar (Tools) -->
          <div class="space-y-6">
             <!-- Toolbox -->
             <div class="st-acrylic p-4 rounded-xl">
               <h3 class="text-white font-semibold mb-3">Adicionar Campo</h3>
               <div class="grid grid-cols-2 gap-2">
                  <button phx-click="add_field" phx-value-type="text" class="btn btn-sm btn-outline text-blue-200 hover:bg-blue-500/20"><.icon name="hero-bars-2" class="mr-1 size-4"/> Texto</button>
                  <button phx-click="add_field" phx-value-type="number" class="btn btn-sm btn-outline text-green-200 hover:bg-green-500/20"><.icon name="hero-hashtag" class="mr-1 size-4"/> Número</button>
                  <button phx-click="add_field" phx-value-type="textarea" class="btn btn-sm btn-outline text-purple-200 hover:bg-purple-500/20"><.icon name="hero-document-text" class="mr-1 size-4"/> Área Disp.</button>
                  <button phx-click="add_field" phx-value-type="checkbox" class="btn btn-sm btn-outline text-yellow-200 hover:bg-yellow-500/20"><.icon name="hero-check-circle" class="mr-1 size-4"/> Checkbox</button>
                  <button phx-click="add_field" phx-value-type="radio" class="btn btn-sm btn-outline text-orange-200 hover:bg-orange-500/20"><.icon name="hero-stop-circle" class="mr-1 size-4"/> Radio</button>
                  <button phx-click="add_field" phx-value-type="select" class="btn btn-sm btn-outline text-teal-200 hover:bg-teal-500/20"><.icon name="hero-list-bullet" class="mr-1 size-4"/> Lista</button>
                  <button phx-click="add_field" phx-value-type="file" class="btn btn-sm btn-outline text-pink-200 hover:bg-pink-500/20"><.icon name="hero-arrow-up-tray" class="mr-1 size-4"/> Upload</button>
               </div>
             </div>
          </div>
        </div>
      </div>


      <%= if @active_field do %>
        <.modal id="field-editor-modal" show on_cancel={JS.push("cancel_edit")} transparent={true}>
           <.live_component
              module={StarTicketsWeb.Admin.Forms.FieldFormComponent}
              id={@active_field.id}
              field={@active_field}
           />
        </.modal>
      <% end %>

    </div>
    """
  end

  def handle_event("add_field", %{"type" => type}, socket) do
    position = length(socket.assigns.fields) + 1

    params = %{
      "label" => "Novo Campo #{type}",
      "type" => type,
      "position" => position,
      "form_template_id" => socket.assigns.template.id,
      "required" => false,
      "options" => %{}
    }

    case Forms.create_field(params) do
      {:ok, field} ->
        fields = Forms.list_fields(socket.assigns.template.id)

        {:noreply,
         socket
         |> assign(:fields, fields)
         |> put_flash(:info, "Campo adicionado!")
         |> assign(:active_field, field)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao criar campo")}
    end
  end

  def handle_event("delete_field", %{"id" => id}, socket) do
    field = Forms.get_field!(id)
    Forms.delete_field(field)
    fields = Forms.list_fields(socket.assigns.template.id)

    {:noreply,
     socket
     |> assign(:fields, fields)
     |> put_flash(:info, "Campo removido!")}
  end

  def handle_event("edit_field", %{"id" => id}, socket) do
    field = Forms.get_field!(id)
    {:noreply, assign(socket, :active_field, field)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :active_field, nil)}
  end

  def handle_event("move_field", %{"id" => id, "direction" => direction}, socket) do
    field = Forms.get_field!(id)

    case Forms.move_field(field, direction) do
      {:ok, _} ->
        fields = Forms.list_fields(socket.assigns.template.id)
        {:noreply, assign(socket, :fields, fields)}

      {:error, _} ->
        # Ignore if invalid move
        {:noreply, socket}
    end
  end

  def handle_info({StarTicketsWeb.Admin.Forms.FieldFormComponent, {:saved, _field}}, socket) do
    fields = Forms.list_fields(socket.assigns.template.id)

    {:noreply,
     socket
     |> assign(:active_field, nil)
     |> assign(:fields, fields)
     |> put_flash(:info, "Campo atualizado!")}
  end
end
