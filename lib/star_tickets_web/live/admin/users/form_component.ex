defmodule StarTicketsWeb.Admin.Users.FormComponent do
  use StarTicketsWeb, :live_component

  alias StarTickets.Accounts
  alias StarTickets.Accounts.UserNotifier

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-acrylic-strong p-6 rounded-2xl shadow-2xl">
      <.header>
        <div class="flex items-center gap-3">
          <div class="bg-primary/20 w-12 h-12 flex items-center justify-center rounded-full backdrop-blur-sm">
            <.icon name="hero-user-plus" class="size-6 text-primary" />
          </div>
          <div class="text-white">
            <span class="text-3xl font-semibold">{@title}</span>
            <div class="text-base font-normal text-gray-300">
              Dados do Usuário - Preencha as informações de acesso
            </div>
          </div>
        </div>
        <hr class="my-4 border-white/40 border-dashed" />
      </.header>

      <.simple_form
        for={@form}
        id="user-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="flex flex-col md:flex-row gap-8">
          <div class="flex-1 space-y-2">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.input field={@form[:name]} type="text" label="Nome Completo" placeholder="Ex: João Silva" />
              <.input field={@form[:username]} type="text" label="Username" placeholder="Ex: joao.silva" />
            </div>

            <.input field={@form[:email]} type="email" label="Email" placeholder="joao@email.com" />

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.input
                field={@form[:password]}
                type="password"
                label={if @action == :new, do: "Senha Inicial", else: "Nova Senha (opcional)"}
                value={@form[:password].value}
              />
              <.input
                field={@form[:role]}
                type="select"
                label="Função (Role)"
                options={role_options()}
                prompt="Selecione uma função"
                required
              />
            </div>

            <% is_admin = @form[:role].value == "admin" %>
            <div class={if is_admin, do: "hidden", else: ""}>
              <.input
                field={@form[:establishment_id]}
                type="select"
                label="Estabelecimento"
                options={@establishments}
                prompt="Selecione um estabelecimento"
                required={not is_admin}
              />
            </div>

            <input type="hidden" name="user[client_id]" value={@client_id} />
          </div>

          <!-- Sidebar com Dicas e Preview -->
          <div class="w-full md:w-72 hidden md:block">
            <div class="bg-white/5 border border-white/10 p-4 rounded-lg text-sm space-y-4 h-full backdrop-blur-md">
              <h4 class="font-bold flex items-center gap-2 text-white">
                <.icon name="hero-information-circle" class="size-6" />
                Informações
              </h4>

              <div class="bg-blue-600/40 border border-blue-500/40 p-3 rounded text-blue-100">
                <strong>Permissões:</strong>
                <ul class="list-disc ml-4 mt-1 space-y-1 text-xs">
                  <li><strong>Admin:</strong> Acesso total</li>
                  <li><strong>Manager:</strong> Gestão local</li>
                  <li><strong>Recepção:</strong> Emitir senhas</li>
                  <li><strong>Profissional:</strong> Chamar senhas</li>
                  <li><strong>TV/Totem:</strong> Dispositivos</li>
                </ul>
              </div>

              <div class="bg-black/40 border border-white/10 p-3 rounded">
                <div class="text-gray-400 text-xs mb-1">Exemplo de Login:</div>
                <div class="font-mono text-white text-md break-all">
                  {preview_login(@client_slug, @form[:establishment_id].value, @form[:username].value, @establishments_map)}
                </div>
                <div class="text-xs text-gray-400 mt-1 text-right">(cliente . estabelecimento . usuario)</div>
              </div>
            </div>
          </div>
        </div>

        <div :if={@form.source.action in [:insert, :update] and not @form.source.valid?} class="my-4 text-center">
           <div class="inline-flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-red-500/20 border border-red-500/20 text-white font-medium">
            <.icon name="hero-exclamation-circle" class="size-5 text-red-400" />
            <span :if={@form[:email].errors != []}>Email: {translate_error(List.first(@form[:email].errors))}</span>
            <span :if={@form[:email].errors == []}>Verifique os erros no formulário</span>
          </div>
        </div>

        <hr class="my-4 border-white/40 border-dashed" />

        <:actions>
          <.link patch={@patch} class="btn btn-ghost text-white hover:bg-white/10 hover:shadow-none">Cancelar</.link>
          <.button phx-disable-with="Salvando..." class="btn bg-orange-600/40 backdrop-blur-md border border-orange-500/90 text-white hover:bg-orange-600/50 shadow-lg">Salvar Usuário</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    client_id =
      (assigns[:current_user_scope] && assigns[:current_user_scope].user.client_id) ||
        user.client_id

    # Load establishments for the select
    # Optimization needed later?
    establishments =
      Accounts.list_establishments(%{"per_page" => "100", "client_id" => client_id})

    establishments_options = Enum.map(establishments, &{&1.name, &1.id})
    establishments_map = Map.new(establishments, &{to_string(&1.id), &1.code})

    # Load client slug for preview
    client = Accounts.get_client!(client_id)

    changeset = Accounts.change_user(user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:client_id, client_id)
     |> assign(:client_slug, client.slug)
     |> assign(:establishments, establishments_options)
     |> assign(:establishments_map, establishments_map)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        notify_parent({:saved, user, "Usuário atualizado com sucesso!"})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user(socket, :new, user_params) do
    # Force client_id from context just in case
    user_params = Map.put(user_params, "client_id", socket.assigns.client_id)

    case Accounts.create_user(user_params) do
      {:ok, user} ->
        # Send welcome email - use Endpoint.url() since we're in a LiveComponent
        login_url = StarTicketsWeb.Endpoint.url() <> "/users/log-in"
        UserNotifier.deliver_welcome_instructions(user, login_url)

        notify_parent({:saved, user, "Usuário criado com sucesso! Email de boas-vindas enviado."})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp role_options do
    [
      {"Recepção", "reception"},
      {"Profissional", "professional"},
      {"Gerente", "manager"},
      {"TV (Painel)", "tv"},
      {"Totem", "totem"},
      {"Admin", "admin"}
    ]
  end

  defp preview_login(client_slug, establishment_id, username, est_map) do
    est_slug = Map.get(est_map, to_string(establishment_id), "est")
    user_part = if is_nil(username) || username == "", do: "usuario", else: username
    "#{client_slug}.#{est_slug}.#{user_part}" |> String.downcase()
  end
end
