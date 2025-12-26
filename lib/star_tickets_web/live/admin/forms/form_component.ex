defmodule StarTicketsWeb.Admin.Forms.FormComponent do
  use StarTicketsWeb, :live_component

  alias StarTickets.Forms

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-acrylic-strong p-6 rounded-2xl shadow-2xl">
      <.header>
        <div class="flex items-center gap-3">
          <div class="bg-primary/20 w-12 h-12 flex items-center justify-center rounded-full backdrop-blur-sm">
            <.icon name="hero-document-text" class="size-6 text-primary" />
          </div>
          <div class="text-white">
            <span class="text-3xl font-semibold">{@title}</span>
            <div class="text-base font-normal text-gray-300">
              Dados do Modelo de Formulário
            </div>
          </div>
        </div>
        <hr class="my-4 border-white/40 border-dashed" />
      </.header>

      <.simple_form
        for={@form}
        id="form-template-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:name]} type="text" label="Nome do Formulário" placeholder="Ex: Anamnese Facial" required />
          <.input field={@form[:description]} type="textarea" label="Descrição" placeholder="Instruções ou objetivo deste formulário" />

          <input type="hidden" name="form_template[client_id]" value={@client_id} />
        </div>

        <div :if={@form.source.action in [:insert, :update] and not @form.source.valid?} class="my-4 text-center">
           <div class="inline-flex items-center justify-center gap-2 px-4 py-2 rounded-lg bg-red-500/20 border border-red-500/20 text-white font-medium">
            <.icon name="hero-exclamation-circle" class="size-5 text-red-400" />
            <span>Verifique os erros no formulário</span>
          </div>
        </div>

        <hr class="my-4 border-white/40 border-dashed" />

        <:actions>
          <.link patch={@patch} class="btn btn-ghost text-white hover:bg-white/10 hover:shadow-none">Cancelar</.link>
          <.button phx-disable-with="Salvando..." class="btn bg-orange-600/40 backdrop-blur-md border border-orange-500/90 text-white hover:bg-orange-600/50 shadow-lg">Salvar Modelo</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{form_template: form_template} = assigns, socket) do
    changeset = Forms.change_template(form_template)

    client_id =
      (assigns[:current_user_scope] && assigns[:current_user_scope].user.client_id) ||
        form_template.client_id

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:client_id, client_id)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"form_template" => params}, socket) do
    changeset =
      socket.assigns.form_template
      |> Forms.change_template(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"form_template" => params}, socket) do
    save_template(socket, socket.assigns.action, params)
  end

  defp save_template(socket, :edit, params) do
    case Forms.update_template(socket.assigns.form_template, params) do
      {:ok, template} ->
        notify_parent({:saved, template, "Formulário atualizado com sucesso!"})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_template(socket, :new, params) do
    params = Map.put(params, "client_id", socket.assigns.client_id)

    case Forms.create_template(params) do
      {:ok, template} ->
        notify_parent({:saved, template, "Formulário criado com sucesso!"})
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
