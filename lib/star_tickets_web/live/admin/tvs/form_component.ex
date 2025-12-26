defmodule StarTicketsWeb.Admin.TVs.FormComponent do
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
            <.icon name="hero-tv" class="size-6 text-primary" />
          </div>
          <div class="text-white">
            <span class="text-3xl font-semibold">{@title}</span>
            <div class="text-base font-normal text-gray-300">
              Gerencie as informações da TV
            </div>
          </div>
        </div>
        <hr class="my-4 border-white/40 border-dashed" />
      </.header>

      <.simple_form
        for={@form}
        id="tv-form"
        phx-target={@myself}
        phx-submit="save"
        phx-change="validate"
      >
        <div class="flex flex-col md:flex-row gap-8">
          <!-- Left Column: Inputs -->
          <div class="flex-1 space-y-4">
            <.input field={@form[:name]} type="text" label="Nome da TV" placeholder="Ex: Recepção, Hall Entrada" />

            <%= if @action == :new do %>
              <.input field={@form[:password]} type="text" label="Senha de Acesso" placeholder="Defina a senha da TV" />
              <p class="text-xs text-white/40 -mt-2">Senha para o usuário da TV logar no sistema.</p>
            <% else %>
               <.input field={@form[:password]} type="text" label="Redefinir Senha" placeholder="Deixe em branco para manter a atual" />
            <% end %>

            <div class="bg-white/5 p-4 rounded-lg border border-white/10 space-y-4">
              <label class="flex items-center gap-3 cursor-pointer">
                <.input field={@form[:news_enabled]} type="checkbox" label="Habilitar Notícias (RSS/URL)" />
              </label>

              <%= if Ecto.Changeset.get_field(@form.source, :news_enabled) do %>
                <.input field={@form[:news_url]} type="text" label="URL da Notícia/Vídeo" placeholder="https://..." />
              <% end %>
            </div>

            <div>
              <div class="flex items-center justify-between mb-2">
                <label class="block text-sm font-medium text-white/80">Serviços Exibidos</label>
                <div class="flex items-center gap-2">
                   <label class="flex items-center gap-2 cursor-pointer text-xs bg-blue-500/20 px-2 py-1 rounded border border-blue-500/30 text-blue-200 hover:bg-blue-500/30 transition-colors select-none">
                    <.input field={@form[:all_services]} type="checkbox" class="checkbox-xs checkbox-primary" />
                    <span>Exibir Todos (Futuros Inclusive)</span>
                  </label>
                </div>
              </div>

              <% all_services = Ecto.Changeset.get_field(@form.source, :all_services) %>

              <div class={"bg-black/20 rounded border border-white/5 p-3 h-60 overflow-y-auto space-y-2 relative transition-opacity duration-300 " <> (if all_services, do: "opacity-50 pointer-events-none", else: "")}>
                <%= for service <- @services do %>
                  <label class="flex items-center gap-3 cursor-pointer group hover:bg-white/5 p-2 rounded transition-colors">
                     <input
                       type="checkbox"
                       name="tv[service_ids][]"
                       value={service.id}
                       checked={service.id in @selected_service_ids}
                       class="checkbox checkbox-sm checkbox-primary border-white/30"
                     />
                     <span class="text-white group-hover:text-blue-300"><%= service.name %></span>
                  </label>
                <% end %>
                <%= if Enum.empty?(@services) do %>
                  <p class="text-white/40 text-sm text-center py-4">Nenhum serviço disponível.</p>
                <% end %>

                <%= if all_services do %>
                    <div class="absolute inset-0 flex items-center justify-center z-10">
                      <span class="bg-black/80 text-white px-3 py-1 rounded text-sm font-semibold backdrop-blur-md border border-white/20 shadow-xl">
                        Todos os serviços serão exibidos
                      </span>
                    </div>
                 <% end %>
              </div>

              <.error :for={msg <- @form[:services].errors}><%= translate_error(msg) %></.error>

              <p class="text-xs text-white/40 mt-1">Selecione quais serviços esta TV deve monitorar.</p>
            </div>
          </div>

          <!-- Right Column: Info -->
          <div class="w-full md:w-72 hidden md:block">
            <div class="bg-white/5 border border-white/10 p-4 rounded-lg text-sm space-y-4 h-full backdrop-blur-md">
              <h4 class="font-bold flex items-center gap-2 text-white">
                <.icon name="hero-information-circle" class="size-6" />
                Informações
              </h4>

              <div class="bg-blue-600/40 border border-blue-500/40 p-3 rounded text-blue-100">
                <strong>Acesso ao Sistema:</strong>
                <p class="mt-1 text-xs">O sistema gera automaticamente um usuário para esta TV.</p>
              </div>

              <div class="bg-black/40 border border-white/10 p-3 rounded">
                <div class="text-gray-400 text-xs mb-1">Login (Gerado):</div>
                <div class="font-mono text-white text-md break-all">
                  <%= preview_login(@establishment, @form[:name].value) %>
                </div>
                <div class="text-xs text-gray-400 mt-1 text-right">(cliente . estabelecimento . tv . nome)</div>
              </div>

              <%= if @action == :edit do %>
                <p class="text-xs text-white/50 bg-white/5 p-2 rounded">
                  <span class="text-yellow-300">Nota:</span> Se alterar o nome da TV, o login do usuário pode não mudar automaticamente para evitar perda de acesso.
                </p>
              <% else %>
                <p class="text-xs text-white/50">
                   Utilize este usuário e a senha definida para logar na Smart TV ou Box.
                </p>
              <% end %>
            </div>
          </div>
        </div>

        <hr class="my-4 border-white/40 border-dashed" />

        <:actions>
          <.link patch={@patch} class="btn btn-ghost text-white hover:bg-white/10 hover:shadow-none">Cancelar</.link>
          <.button phx-disable-with="Salvando..." class="btn bg-orange-600/40 backdrop-blur-md border border-orange-500/90 text-white hover:bg-orange-600/50 shadow-lg">Salvar TV</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{tv: tv} = assigns, socket) do
    # Preload client needed for login preview
    establishment = Accounts.get_establishment!(assigns.establishment_id) |> Repo.preload(:client)
    services = Accounts.list_services(%{"client_id" => establishment.client_id})

    # Preload if editing
    tv = Repo.preload(tv, [:services, :user])

    selected_service_ids = Enum.map(tv.services || [], & &1.id)
    changeset = Accounts.change_tv(tv)

    {:ok,
     socket
     |> assign(assigns)
     # Assign establishment for render
     |> assign(:establishment, establishment)
     |> assign(:services, services)
     |> assign(:selected_service_ids, selected_service_ids)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"tv" => tv_params}, socket) do
    # Fix checkbox disappearing issue: update selected_service_ids state from params
    selected_ids =
      (tv_params["service_ids"] || [])
      |> Enum.map(&String.to_integer/1)

    changeset =
      socket.assigns.tv
      |> Accounts.change_tv(tv_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:selected_service_ids, selected_ids)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"tv" => tv_params}, socket) do
    save_tv(socket, socket.assigns.action, tv_params)
  end

  defp save_tv(socket, :edit, tv_params) do
    case Accounts.update_tv(socket.assigns.tv, tv_params) do
      {:ok, tv} ->
        notify_parent({:saved, tv})

        {:noreply,
         socket
         |> put_flash(:info, "TV atualizada com sucesso")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_tv(socket, :new, tv_params) do
    # Inject establishment_id
    tv_params = Map.put(tv_params, "establishment_id", socket.assigns.establishment_id)

    case Accounts.create_tv(tv_params) do
      {:ok, tv} ->
        notify_parent({:saved, tv})

        {:noreply,
         socket
         |> put_flash(:info, "TV criada com sucesso")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp preview_login(establishment, tv_name) do
    slug_name =
      (tv_name || "tv")
      |> String.normalize(:nfd)
      |> String.replace(~r/\p{Mn}/u, "")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]/, "_")

    "#{establishment.client.slug}.#{establishment.code}.tv.#{slug_name}" |> String.downcase()
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
