defmodule StarTicketsWeb.Admin.Forms.FieldFormComponent do
  @moduledoc false

  use StarTicketsWeb, :live_component

  alias StarTickets.Forms

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-acrylic-strong p-6 rounded-2xl shadow-2xl">
      <h3 class="text-xl font-bold text-white mb-4">Editar Campo</h3>

      <.simple_form
        for={@form}
        id="field-form"
        phx-target={@myself}
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:label]} type="text" label="Rótulo (Pergunta)" required />
          <%= if @field.type in ["text", "number", "textarea", "select"] do %>
            <.input
              field={@form[:placeholder]}
              type="text"
              label="Placeholder (Dica de preenchimento)"
            />
          <% end %>

          <div class="flex items-center gap-2 pt-2">
            <.input field={@form[:required]} type="checkbox" label="Obrigatório?" />
          </div>

          <%= if @field.type in ["select", "radio", "checkbox"] do %>
            <div class="form-control">
              <label class="label text-white">Opções (uma por linha)</label>
              <textarea
                name="options_text"
                class="textarea textarea-bordered bg-white/10 text-white h-32"
                placeholder="Opção 1&#10;Opção 2&#10;valor: Rótulo customizado"
              >{@options_text}</textarea>
              <p class="text-xs text-gray-400 mt-1">
                Para valores personalizados use: <code>valor: Rótulo</code>
              </p>
            </div>
          <% end %>

          <input type="hidden" name="field[type]" value={@field.type} />
        </div>

        <:actions>
          <button type="button" phx-click="cancel_edit" class="btn btn-ghost text-white">
            Cancelar
          </button>
          <.button class="btn btn-primary">Salvar Alterações</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{field: field} = assigns, socket) do
    changeset = Forms.change_field(field)

    # Auto-clear default label for better UX
    changeset =
      if String.starts_with?(field.label, "Novo Campo") do
        Ecto.Changeset.change(changeset, %{label: ""})
      else
        changeset
      end

    # Parse options to text for display
    options_text =
      case field.options do
        %{"items" => list} when is_list(list) ->
          Enum.map_join(list, "\n", fn
            %{"label" => label, "value" => value} when label != value -> "#{value}: #{label}"
            %{"label" => label} -> label
            item -> item
          end)

        _ ->
          ""
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:options_text, options_text)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("save", %{"field" => field_params} = params, socket) do
    # Parse options text back to map/list
    field_params =
      if socket.assigns.field.type in ["select", "radio", "checkbox"] do
        raw_text = params["options_text"] || ""
        options = parse_options(raw_text)
        Map.put(field_params, "options", %{"items" => options})
      else
        field_params
      end

    case Forms.update_field(socket.assigns.field, field_params) do
      {:ok, field} ->
        notify_parent({:saved, field})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp parse_options(text) do
    text
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      case String.split(line, ":", parts: 2) do
        [val, label] -> %{"value" => String.trim(val), "label" => String.trim(label)}
        [val] -> %{"value" => String.trim(val), "label" => String.trim(val)}
      end
    end)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "field"))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
