defmodule StarTicketsWeb.Admin.Services.FormComponent do
  use StarTicketsWeb, :live_component

  alias StarTickets.Accounts
  alias StarTickets.Forms

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-acrylic-strong p-6 rounded-2xl shadow-2xl">
      <.header>
        <div class="flex items-center gap-3">
          <div class="bg-primary/20 w-12 h-12 flex items-center justify-center rounded-full backdrop-blur-sm">
            <.icon name="hero-wrench-screwdriver" class="size-6 text-primary" />
          </div>
          <div class="text-white">
            <span class="text-3xl font-semibold">{@title}</span>
            <div class="text-base font-normal text-gray-300">
              Dados do Serviço - Configuração Global
            </div>
          </div>
        </div>
        <hr class="my-4 border-white/40 border-dashed" />
      </.header>

      <.simple_form
        for={@form}
        id="service-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <!-- Info Box Global -->
          <div class="bg-blue-600/20 border border-blue-500/40 p-4 rounded-lg flex gap-3 text-blue-100 items-start">
            <.icon name="hero-information-circle" class="size-6 shrink-0 mt-0.5" />
            <div class="text-sm">
              <p class="font-bold mb-1">Informação Importante:</p>
              <p>
                Os serviços cadastrados aqui representam <strong>todos os serviços prestados</strong>
                por todos os estabelecimentos do cliente.
              </p>
              <p class="mt-2 text-blue-200 text-xs">
                Futuramente, você poderá relacionar as salas de cada estabelecimento com um ou mais destes serviços.
              </p>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <.input
              field={@form[:name]}
              type="text"
              label="Nome do Serviço"
              placeholder="Ex: Consulta Geral"
              required
            />
            <.input
              field={@form[:duration]}
              type="number"
              label="Duração (minutos)"
              placeholder="Ex: 30"
              required
              min="1"
            />
          </div>

          <.input
            field={@form[:form_template_id]}
            type="select"
            label="Formulário de Atendimento (Opcional)"
            options={@templates}
            prompt="Selecione um formulário..."
          />

          <input type="hidden" name="service[client_id]" value={@client_id} />
        </div>

        <div
          :if={@form.source.action in [:insert, :update] and not @form.source.valid?}
          class="my-4 text-center"
        >
          <div class="inline-flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-red-500/20 border border-red-500/20 text-white font-medium">
            <.icon name="hero-exclamation-circle" class="size-5 text-red-400" />
            <span>Verifique os erros no formulário</span>
          </div>
        </div>

        <hr class="my-4 border-white/40 border-dashed" />

        <:actions>
          <.link patch={@patch} class="btn btn-ghost text-white hover:bg-white/10 hover:shadow-none">
            Cancelar
          </.link>
          <.button
            phx-disable-with="Salvando..."
            class="btn bg-orange-600/40 backdrop-blur-md border border-orange-500/90 text-white hover:bg-orange-600/50 shadow-lg"
          >
            Salvar Serviço
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{service: service} = assigns, socket) do
    changeset = Accounts.change_service(service)

    client_id =
      (assigns[:current_user_scope] && assigns[:current_user_scope].user.client_id) ||
        service.client_id

    templates = Forms.list_template_options(client_id) |> Enum.map(&{&1.name, &1.id})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:client_id, client_id)
     |> assign(:templates, templates)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"service" => service_params}, socket) do
    changeset =
      socket.assigns.service
      |> Accounts.change_service(service_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"service" => service_params}, socket) do
    save_service(socket, socket.assigns.action, service_params)
  end

  defp save_service(socket, :edit, service_params) do
    case Accounts.update_service(socket.assigns.service, service_params) do
      {:ok, service} ->
        notify_parent({:saved, service, "Serviço atualizado com sucesso!"})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_service(socket, :new, service_params) do
    # Force client_id
    service_params = Map.put(service_params, "client_id", socket.assigns.client_id)

    case Accounts.create_service(service_params) do
      {:ok, service} ->
        notify_parent({:saved, service, "Serviço criado com sucesso!"})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
