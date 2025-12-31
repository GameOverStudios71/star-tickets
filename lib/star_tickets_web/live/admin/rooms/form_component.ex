defmodule StarTicketsWeb.Admin.Rooms.FormComponent do
  use StarTicketsWeb, :live_component

  alias StarTickets.Accounts
  alias StarTickets.Repo

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-acrylic-strong p-6 rounded-2xl shadow-2xl">
      <.header>
        <div class="flex items-center gap-3">
          <div class="bg-primary/20 w-12 h-12 flex items-center justify-center rounded-full backdrop-blur-sm">
            <.icon name="hero-home" class="size-6 text-primary" />
          </div>
          <div class="text-white">
            <span class="text-3xl font-semibold">{@title}</span>
            <div class="text-base font-normal text-gray-300">
              Gerencie as informações da sala
            </div>
          </div>
        </div>
        <hr class="my-4 border-white/40 border-dashed" />
      </.header>

      <.simple_form
        for={@form}
        id="room-form"
        phx-target={@myself}
        phx-submit="save"
        phx-change="validate"
      >
        <div class="flex flex-col md:flex-row gap-8">
          <div class="flex-1 space-y-4">
            <.input field={@form[:name]} type="text" label="Nome da Posição" placeholder="Ex: Guichê 1, Consultório A, Mesa 2" />

            <div class="flex gap-4">
              <div class="flex-1">
                <.input
                  field={@form[:type]}
                  type="select"
                  label="Tipo de Posição"
                  options={[
                    {"Recepção", "reception"},
                    {"Profissional", "professional"}
                  ]}
                />
              </div>
              <div class="flex items-end pb-1">
                <.input field={@form[:is_active]} type="checkbox" label="Ativa" />
              </div>
            </div>

            <.input field={@form[:capacity_threshold]} type="number" label="Capacidade Máxima (Pessoas)" />

            <% type_value = Phoenix.HTML.Form.input_value(@form, :type) %>
            <%= if type_value == "professional" || type_value == :professional do %>
              <div>
                <div class="flex items-center justify-between mb-2">
                  <label class="block text-sm font-medium text-white/80">Serviços Atendidos</label>
                  <div class="flex items-center gap-2">
                     <label class="flex items-center gap-2 cursor-pointer text-xs bg-blue-500/20 px-2 py-1 rounded border border-blue-500/30 text-blue-200 hover:bg-blue-500/30 transition-colors select-none">
                      <.input field={@form[:all_services]} type="checkbox" class="checkbox-xs checkbox-primary" />
                      <span>Atender Todos os Serviços</span>
                    </label>
                  </div>
                </div>

                <% all_services = Ecto.Changeset.get_field(@form.source, :all_services) %>

                <div class={"bg-black/20 rounded border border-white/5 p-3 h-80 overflow-y-auto space-y-2 relative transition-opacity duration-300 " <> (if all_services, do: "opacity-50 pointer-events-none", else: "")}>
                  <%= for service <- @services do %>
                    <label class="flex items-center gap-3 cursor-pointer group hover:bg-white/5 p-2 rounded transition-colors">
                       <input
                         type="checkbox"
                         name="room[service_ids][]"
                         value={service.id}
                         checked={service.id in @selected_service_ids}
                         class="checkbox checkbox-sm checkbox-primary border-white/30"
                       />
                       <span class="text-white group-hover:text-blue-300"><%= service.name %></span>
                    </label>
                  <% end %>
                  <%= if Enum.empty?(@services) do %>
                    <p class="text-white/40 text-sm text-center py-4">Nenhum serviço disponível neste estabelecimento.</p>
                  <% end %>

                  <%= if all_services do %>
                      <div class="absolute inset-0 flex items-center justify-center z-10">
                        <span class="bg-black/80 text-white px-3 py-1 rounded text-sm font-semibold backdrop-blur-md border border-white/20 shadow-xl">
                          Todos os serviços serão atendidos
                        </span>
                      </div>
                   <% end %>
                </div>
                <.error :for={msg <- @form[:services].errors}>{translate_error(msg)}</.error>
                <p class="text-xs text-white/40 mt-1">Selecione um ou mais serviços que esta sala atende, ou marque "Atender Todos".</p>
              </div>
            <% else %>
              <div class="p-4 bg-white/5 border border-white/10 rounded-lg text-sm text-gray-300">
                <strong class="block text-white mb-2">ℹ️ Configuração Automática</strong>
                <p>Salas de Recepção atendem automaticamente toda a demanda de chegada (senhas aguardando).</p>
                <p class="mt-2 text-xs text-white/50">Não é necessário selecionar serviços específicos.</p>
              </div>
            <% end %>
          </div>

          <div class="w-full md:w-72 hidden md:block">
            <div class="bg-white/5 border border-white/10 p-4 rounded-lg text-sm space-y-4 h-full backdrop-blur-md">
              <h4 class="font-bold flex items-center gap-2 text-white">
                <.icon name="hero-information-circle" class="size-6" />
                Sobre a Capacidade
              </h4>

              <div class="space-y-4 text-gray-300">
                <p>Este número define quando a fila da sala é considerada "cheia".</p>

                <div class="p-3 bg-blue-600/40 border border-blue-500/40 rounded-md text-xs text-blue-100">
                  <strong class="block mb-1 text-blue-200">Exemplo Prático:</strong>
                  Se a sala de espera principal comporta 50 pessoas e você possui 2 salas de atendimento iguais,
                  divida o total por 2. Cada sala deve ter capacidade de 25 pessoas.
                </div>
              </div>
            </div>
          </div>
        </div>

        <hr class="my-4 border-white/40 border-dashed" />

        <:actions>
          <.link patch={@patch} class="btn btn-ghost text-white hover:bg-white/10 hover:shadow-none">Cancelar</.link>
          <.button phx-disable-with="Salvando..." class="btn bg-orange-600/40 backdrop-blur-md border border-orange-500/90 text-white hover:bg-orange-600/50 shadow-lg">Salvar Sala</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{room: room} = assigns, socket) do
    # Fetch establishment to get client_id to filter services
    establishment = Accounts.get_establishment!(assigns.establishment_id)

    # List services for this client
    services = Accounts.list_services(%{"client_id" => establishment.client_id})

    # Preload room services if not loaded
    # room passed from list might have services loaded, but if new struct, it's empty
    room = Repo.preload(room, :services)

    selected_service_ids = Enum.map(room.services, & &1.id)
    changeset = Accounts.change_room(room)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))
     |> assign(:services, services)
     |> assign(:selected_service_ids, selected_service_ids)}
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    selected_ids =
      (room_params["service_ids"] || [])
      |> Enum.map(&String.to_integer/1)

    changeset =
      socket.assigns.room
      |> Accounts.change_room(room_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:selected_service_ids, selected_ids)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"room" => room_params}, socket) do
    save_room(socket, socket.assigns.action, room_params)
  end

  defp save_room(socket, :edit, room_params) do
    # room_params might be missing "service_ids" if no checkbox checked.
    # HTML form doesn't send unchecked checkboxes.
    # SimpleForm inputs use hidden input hack for single checkboxes, but for manual list:
    # If using name="room[service_ids][]", if none checked, key is missing.
    # Ecto might interpret missing as "no update".
    # We want "replace with empty".
    # So we must ensure "service_ids" key exists.

    room_params = Map.put_new(room_params, "service_ids", [])

    case Accounts.update_room(socket.assigns.room, room_params) do
      {:ok, room} ->
        notify_parent({:saved, room})

        {:noreply,
         socket
         |> put_flash(:info, "Sala atualizada com sucesso")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_room(socket, :new, room_params) do
    room_params =
      room_params
      |> Map.put("establishment_id", socket.assigns.establishment_id)
      |> Map.put_new("service_ids", [])

    case Accounts.create_room(room_params) do
      {:ok, room} ->
        notify_parent({:saved, room})

        {:noreply,
         socket
         |> put_flash(:info, "Sala criada com sucesso")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
