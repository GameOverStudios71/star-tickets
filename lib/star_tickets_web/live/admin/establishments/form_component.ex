defmodule StarTicketsWeb.Admin.Establishments.FormComponent do
  use StarTicketsWeb, :live_component

  alias StarTickets.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-acrylic-strong p-6 rounded-2xl shadow-2xl">
      <.header>
        <div class="flex items-center gap-3">
          <div class="bg-primary/20 w-12 h-12 flex items-center justify-center rounded-full backdrop-blur-sm">
            <.icon name="hero-building-office-2" class="size-6 text-primary" />
          </div>
          <div class="text-white">
            <span class="text-3xl font-semibold">{@title}</span>
            <div class="text-base font-normal text-gray-300">
              Gerencie as informações do estabelecimento
            </div>
          </div>
        </div>
        <hr class="my-4 border-white/40 border-dashed" />
      </.header>

      <.simple_form
        for={@form}
        id="establishment-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="flex flex-col md:flex-row gap-8">
          <div class="flex-1 space-y-2">
            <.input
              field={@form[:name]}
              type="text"
              label="Nome do Estabelecimento"
              placeholder="Ex: Matriz - SP"
            />
            <.input field={@form[:code]} type="hidden" />
            <.error
              :for={msg <- @form[:code].errors}
              :if={translate_error(msg) not in ["can't be blank", "não pode ficar em branco"]}
            >
              Código (Slug): {translate_error(msg)}
            </.error>
            <.input
              field={@form[:address]}
              type="text"
              label="Endereço Completo"
              placeholder="Rua, Número, Bairro, Cidade - UF"
            />
            <.input
              field={@form[:phone]}
              type="tel"
              label="Telefone de Contato"
              placeholder="(00) 00000-0000"
              phx-hook="PhoneMask"
            />
            <div class="pt-2">
              <.input field={@form[:is_active]} type="checkbox" label="Estabelecimento Ativo" />
            </div>
          </div>

          <div class="w-full md:w-72 hidden md:block">
            <div class="bg-white/5 border border-white/10 p-4 rounded-lg text-sm space-y-4 h-full backdrop-blur-md">
              <h4 class="font-bold flex items-center gap-2 text-white">
                <.icon name="hero-information-circle" class="size-6" /> Informações
              </h4>

              <div class="space-y-4 text-gray-300">
                <div class="p-3 bg-blue-600/40 border border-blue-500/40 rounded-md text-xs text-blue-100">
                  <strong class="block mb-1 text-blue-200">Atenção ao Login:</strong>
                  O nome do estabelecimento será usado como prefixo para o login dos usuários.
                </div>

                <div>
                  <strong class="text-white">Exemplo de Login:</strong>
                  <div class="mt-2 p-3 bg-black/40 rounded border border-white/10 font-mono text-xs break-all text-white">
                    {slugify_name(@client_name)}.{slugify_name(@form[:name].value || "loja")}.usuario
                  </div>
                  <p class="text-xs mt-1 text-white">
                    (empresa . estabelecimento . usuário)
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div
          :if={@form.source.action in [:insert, :update] and not @form.source.valid?}
          class="my-4 text-center"
        >
          <div class="inline-flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-red-500/20 border border-red-500/20 text-white font-medium">
            <.icon name="hero-exclamation-circle" class="size-5 text-red-400" />
            <span :if={@form[:name].errors != []}>
              Nome: {translate_error(List.first(@form[:name].errors))}
            </span>
            <span :if={@form[:name].errors == []}>Verifique os erros no formulário</span>
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
            Salvar Estabelecimento
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{establishment: establishment} = assigns, socket) do
    changeset = Accounts.change_establishment(establishment)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"establishment" => establishment_params}, socket) do
    # Auto-generate code from name if action is :new
    establishment_params =
      if socket.assigns.action == :new do
        Map.put(establishment_params, "code", slugify_string(establishment_params["name"]))
      else
        establishment_params
      end

    changeset =
      socket.assigns.establishment
      |> Accounts.change_establishment(establishment_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"establishment" => establishment_params}, socket) do
    # Ensure code is set on save as well if needed
    establishment_params =
      if socket.assigns.action == :new do
        establishment_params
        |> Map.put("code", slugify_string(establishment_params["name"]))
        |> Map.put("client_id", socket.assigns.client_id)
      else
        establishment_params
      end

    save_establishment(socket, socket.assigns.action, establishment_params)
  end

  defp save_establishment(socket, :edit, establishment_params) do
    case Accounts.update_establishment(socket.assigns.establishment, establishment_params) do
      {:ok, establishment} ->
        notify_parent({:saved, establishment, "Estabelecimento atualizado com sucesso"})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_establishment(socket, :new, establishment_params) do
    case Accounts.create_establishment(establishment_params) do
      {:ok, establishment} ->
        notify_parent({:saved, establishment, "Estabelecimento criado com sucesso"})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp slugify_string(nil), do: ""

  defp slugify_string(str) do
    str
    |> String.upcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^A-Z0-9\s]/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.slice(0, 20)
  end

  defp slugify_name(name) do
    slugify_string(name) |> String.downcase()
  end
end
