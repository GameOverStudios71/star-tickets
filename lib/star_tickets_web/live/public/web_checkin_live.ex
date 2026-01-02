defmodule StarTicketsWeb.Public.WebCheckinLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Tickets
  alias StarTickets.Forms
  alias StarTickets.Forms.FormField
  alias StarTickets.Forms.FormSection
  alias StarTickets.Repo
  import Ecto.Query

  def mount(%{"token" => token}, _session, socket) do
    ticket = Tickets.get_ticket_by_token!(token)

    # Custom preload to get sorted sections and fields
    fields_query = from(f in FormField, order_by: [asc: f.position])

    sections_query =
      from(s in FormSection, order_by: [asc: s.position], preload: [form_fields: ^fields_query])

    ticket =
      Repo.preload(
        ticket,
        [services: [form_template: [form_fields: fields_query, form_sections: sections_query]]],
        force: true
      )

    # Determine initial step
    initial_step = if ticket.customer_name, do: :forms, else: :name_input

    # Prepare Sections (Flatten services -> sections)
    all_sections =
      ticket.services
      |> Enum.flat_map(fn s ->
        if t = s.form_template do
          if Enum.empty?(t.form_sections) do
            # Fallback: Wrapper section for older forms
            [
              %{
                id: "default_#{t.id}",
                title: t.name,
                description: t.description,
                form_fields: t.form_fields,
                fallback: true
              }
            ]
          else
            t.form_sections
          end
        else
          []
        end
      end)

    # Setup uploads
    socket =
      all_sections
      |> Enum.flat_map(& &1.form_fields)
      |> Enum.filter(&(&1.type == "file"))
      |> Enum.reduce(socket, fn field, sock ->
        allow_upload(sock, String.to_atom("field_#{field.id}"),
          accept: ~w(.jpg .jpeg .png .pdf),
          max_entries: 5
        )
      end)

    {:ok,
     socket
     |> assign(ticket: ticket)
     |> assign(current_step: initial_step)
     |> assign(current_section_index: 0)
     |> assign(sections: all_sections)
     |> assign(customer_name: ticket.customer_name || "")
     |> assign(form_data: %{})}
  end

  def handle_event("validate_name", %{"customer_name" => name}, socket) do
    {:noreply, assign(socket, customer_name: name)}
  end

  def handle_event("save_name", %{"customer_name" => name}, socket) do
    if String.trim(name) == "" do
      {:noreply, put_flash(socket, :error, "Por favor, informe seu nome.")}
    else
      {:ok, updated_ticket} =
        Tickets.update_ticket(socket.assigns.ticket, %{
          customer_name: name,
          webcheckin_status: "IN_PROGRESS",
          webcheckin_started_at: DateTime.utc_now()
        })

      {:noreply, socket |> assign(ticket: updated_ticket, current_step: :forms)}
    end
  end

  def handle_event("validate_forms", params, socket) do
    {:noreply, assign(socket, form_data: params)}
  end

  # Wizard Navigation
  def handle_event("next_section", _params, socket) do
    new_index = min(socket.assigns.current_section_index + 1, length(socket.assigns.sections) - 1)
    # Scroll to top? (handled by client liveview usually if we push event or hook)
    {:noreply, assign(socket, current_section_index: new_index)}
  end

  def handle_event("prev_section", _params, socket) do
    new_index = max(socket.assigns.current_section_index - 1, 0)
    {:noreply, assign(socket, current_section_index: new_index)}
  end

  def handle_event("submit_wizard", _params, socket) do
    # We trigger the form submission manually if separate button
    # But actually the "Enviar" button will be a submit button inside the form.
    # So "save_forms" is called.
    # But wait, usually wizard stores intermediate state.
    # Here we expect all data to be in the form inputs?
    # If we switch sections (hide/show divs), the DOM elements currently hidden MIGHT NOT send their values
    # if they are removed from DOM?
    # If we use CSS hidden (display:none), they send values.
    # If we use `if` in Elixir, they are removed from DOM and values lost!

    # CRITICAL: We must persist form data between steps for LiveView if we remove from DOM.
    # Or strictly use CSS hiding.
    # Given validation requirements and UX, preserving in `form_data` assign is safer.
    # `validate_forms` captures `params`. `form_data` holds it.
    # But params are only what's currently submitted/changed.
    # If fields are removed from DOM, they won't be in subsequent validate events.

    # Alternative: Render ALL sections but hide non-active ones with CSS classes.
    # This is easiest for preserving state without complex merge logic.
    {:noreply, socket}
  end

  def handle_event("save_forms", params, socket) do
    # Merge current params with stored form_data to ensure we have everything?
    # If using CSS hiding, `params` will contain EVERYTHING (assuming inputs are in DOM).
    # I will use CSS hiding for simplicity and robustness.

    ticket = socket.assigns.ticket
    all_fields = Enum.flat_map(socket.assigns.sections, & &1.form_fields)

    responses =
      Enum.map(all_fields, fn field ->
        value =
          case field.type do
            "file" ->
              uploaded_files =
                consume_uploaded_entries(socket, String.to_atom("field_#{field.id}"), fn %{
                                                                                           path:
                                                                                             path
                                                                                         },
                                                                                         entry ->
                  dest_dir = "priv/static/uploads"
                  File.mkdir_p!(dest_dir)
                  dest = Path.join(dest_dir, "#{entry.uuid}-#{entry.client_name}")
                  File.cp!(path, dest)
                  {:ok, "/uploads/#{Path.basename(dest)}"}
                end)

              Enum.join(uploaded_files, ",")

            "checkbox" ->
              val = params["field_#{field.id}"]
              if is_list(val), do: Enum.join(val, ", "), else: val

            _ ->
              params["field_#{field.id}"]
          end

        %{
          ticket_id: ticket.id,
          form_field_id: field.id,
          value: to_string(value || "")
        }
      end)

    Enum.each(responses, &Forms.create_form_response/1)

    # Mark as completed
    {:ok, _} =
      Tickets.update_ticket(ticket, %{
        webcheckin_status: "COMPLETED",
        webcheckin_completed_at: DateTime.utc_now()
      })

    {:noreply, push_navigate(socket, to: ~p"/ticket/#{ticket.token}")}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen text-white p-6 flex flex-col items-center">
      
    <!-- Logo/Header -->
      <div class="text-center mb-8 pt-6 w-full max-w-2xl">
        <h1 class="text-2xl font-bold tracking-tight text-white/80 mb-2">Web Check-in</h1>
        <div class="inline-block px-4 py-1 rounded-full bg-white/10 text-white/60 text-sm font-mono">
          Senha: <span class="text-white font-bold">{@ticket.display_code}</span>
        </div>
      </div>

      <div class="w-[85%] max-w-6xl transition-all duration-500">
        
    <!-- STEP 1: Name Input -->
        <%= if @current_step == :name_input do %>
          <div class="bg-white/10 backdrop-blur-xl border border-white/10 rounded-3xl p-8 shadow-2xl animate-fade-in">
            <div class="text-center mb-8">
              <div class="text-5xl mb-4">👋</div>
              <h2 class="text-2xl font-bold text-white">Bem-vindo(a)!</h2>
              <p class="text-white/60 mt-2">
                Para começarmos o atendimento, precisamos saber seu nome.
              </p>
            </div>

            <form phx-submit="save_name" phx-change="validate_name">
              <div class="mb-8">
                <label class="block text-sm font-medium text-white/80 mb-2">Nome Completo</label>
                <input
                  type="text"
                  name="customer_name"
                  value={@customer_name}
                  class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-4 text-lg text-white placeholder-white/30 focus:border-blue-500/50 focus:ring-2 focus:ring-blue-500/20 outline-none transition-all text-center"
                  placeholder="Digite seu nome aqui..."
                  autofocus
                />
              </div>

              <button
                type="submit"
                class="w-full py-4 rounded-xl font-bold text-white text-lg
                      bg-gradient-to-r from-blue-600 to-indigo-600
                      hover:from-blue-500 hover:to-indigo-500 hover:scale-[1.02]
                      transition-all duration-300 shadow-lg shadow-blue-500/20"
              >
                Continuar
              </button>
            </form>
          </div>
        <% end %>
        
    <!-- STEP 2: Forms / Wizard -->
        <%= if @current_step == :forms do %>
          <form
            phx-submit="save_forms"
            phx-change="validate_forms"
            class="space-y-8 animate-fade-in-up"
          >
            
    <!-- Customer Name Header -->
            <div class="text-center mb-6">
              <p class="text-white/50 text-sm">Atendimento para</p>
              <h3 class="text-xl font-bold text-white">{@customer_name}</h3>
            </div>
            
    <!-- Wizard Progress (Dots) -->
            <%= if length(@sections) > 1 do %>
              <div class="flex justify-center gap-2 mb-8">
                <%= for {_, idx} <- Enum.with_index(@sections) do %>
                  <div class={"w-2 h-2 rounded-full transition-all duration-300 " <>
                         if(idx == @current_section_index, do: "bg-blue-500 scale-125 w-4", else: if(idx < @current_section_index, do: "bg-blue-500/50", else: "bg-white/20"))}>
                  </div>
                <% end %>
              </div>
            <% end %>
            
    <!-- Sections Container (Render all but hide via CSS to preserve state) -->
            <%= for {section, idx} <- Enum.with_index(@sections) do %>
              <div class={"bg-white/10 backdrop-blur-xl border border-white/10 rounded-3xl overflow-hidden shadow-2xl " <> if(idx != @current_section_index, do: "hidden", else: "block")}>
                
    <!-- Section Header -->
                <div class="bg-white/5 border-b border-white/5 p-6">
                  <h2 class="text-xl font-bold text-white flex items-center gap-3">
                    <span class="text-2xl">{if idx == 0, do: "📝", else: "📄"}</span>
                    {section.title}
                  </h2>
                  <!-- Handle fallback struct vs struct -->
                  <%= if Map.has_key?(section, :description) and section.description do %>
                    <p class="text-white/60 text-sm mt-1 ml-9">{section.description}</p>
                  <% end %>
                </div>
                
    <!-- Fields -->
                <div class="p-6 space-y-6">
                  <%= for field <- field_list_for(section) do %>
                    <.render_field
                      field={field}
                      uploads={assigns[:uploads] || %{}}
                      form_data={@form_data}
                    />
                  <% end %>
                </div>
              </div>
            <% end %>
            
    <!-- Wizard Controls -->
            <div class="flex gap-4 pt-4">
              <%= if @current_section_index > 0 do %>
                <button
                  type="button"
                  phx-click="prev_section"
                  class="flex-1 py-4 rounded-xl font-semibold text-white/70 bg-white/5 hover:bg-white/10 transition-all"
                >
                  ← Voltar
                </button>
              <% end %>

              <%= if @current_section_index < length(@sections) - 1 do %>
                <button
                  type="button"
                  phx-click="next_section"
                  class={"flex-1 py-4 rounded-xl font-bold text-white bg-blue-600 hover:bg-blue-500 transition-all shadow-lg shadow-blue-500/20 " <> if(@current_section_index == 0, do: "w-full", else: "")}
                >
                  Continuar →
                </button>
              <% else %>
                <button
                  type="submit"
                  class={"flex-1 py-4 rounded-xl font-bold text-white bg-green-600 hover:bg-green-500 transition-all shadow-lg shadow-green-500/20 " <> if(@current_section_index == 0, do: "w-full", else: "")}
                >
                  Enviar Informações ✓
                </button>
              <% end %>
            </div>
          </form>
        <% end %>
      </div>
    </div>
    """
  end

  defp field_list_for(section) do
    # Helper to handle map (fallback) vs struct
    if Map.has_key?(section, :fallback) do
      section.form_fields
    else
      section.form_fields
    end
  end

  defp is_checked?(form_data, field_name, value) do
    # Checkbox arrays might come as list or map with "true" values
    # Phoenix typically sends list of values for multiple checkboxes with same name="name[]"
    # But here we are checking against `form_data` which is the raw params map from `validate_forms`.
    # `params["field_X"]` might be `["Val1", "Val2"]` (list of strings) or just `nil` or just "Val1" (if only 1 selected?)
    # Usually with `[]` in name, it's always list.

    current_values =
      case Map.get(form_data, field_name) do
        list when is_list(list) -> list
        val when is_binary(val) -> [val]
        _ -> []
      end

    value in current_values
  end

  defp is_radio_checked?(form_data, field_name, value) do
    Map.get(form_data, field_name) == value
  end

  def render_field(assigns) do
    ~H"""
    <div class="form-group">
      <label class="block text-sm font-medium text-white/80 mb-2">
        {@field.label}
        <%= if @field.required do %>
          <span class="text-red-400">*</span>
        <% end %>
      </label>

      <% field_name = "field_#{@field.id}" %>
      
    <!-- Safe access to form_data -->
      <% form_data = assigns[:form_data] || %{} %>

      <%= case @field.type do %>
        <% "text" -> %>
          <input
            type="text"
            name={field_name}
            value={form_data[field_name]}
            class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/30 focus:border-blue-500/50 focus:ring-2 focus:ring-blue-500/20 outline-none transition-all"
            placeholder={@field.placeholder}
          />
        <% "textarea" -> %>
          <textarea
            name={field_name}
            rows="3"
            class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/30 focus:border-blue-500/50 focus:ring-2 focus:ring-blue-500/20 outline-none transition-all"
            placeholder={@field.placeholder}
          >{form_data[field_name]}</textarea>
        <% "number" -> %>
          <input
            type="number"
            name={field_name}
            value={form_data[field_name]}
            class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/30 focus:border-blue-500/50 focus:ring-2 focus:ring-blue-500/20 outline-none transition-all"
            placeholder={@field.placeholder}
          />
        <% "select" -> %>
          <select
            name={field_name}
            class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white focus:border-blue-500/50 focus:ring-2 focus:ring-blue-500/20 outline-none transition-all appearance-none"
          >
            <option value="" class="bg-slate-800 text-white/50">Selecione...</option>
            <% items = (@field.options || %{})["items"] || [] %>
            <%= for item <- items do %>
              <option
                value={item["label"]}
                selected={form_data[field_name] == item["label"]}
                class="bg-slate-800"
              >
                {item["label"]}
              </option>
            <% end %>
          </select>
        <% "checkbox" -> %>
          <% items = (@field.options || %{})["items"] || [] %>
          <% count = length(items) %>
          <% grid_class =
            cond do
              count > 8 -> "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3"
              count > 4 -> "grid grid-cols-1 sm:grid-cols-2 gap-3"
              true -> "space-y-3"
            end %>

          <%= if items != [] do %>
            <div class={grid_class}>
              <%= for item <- items do %>
                <% checked? = is_checked?(form_data, field_name, item["label"]) %>
                <label class={"flex items-center gap-3 cursor-pointer select-none group p-3 rounded-xl transition-all duration-300 border w-full h-full " <>
                   if(checked?,
                      do: "bg-emerald-500/20 border-emerald-500/50 shadow-[0_0_20px_rgba(16,185,129,0.15)] ring-1 ring-emerald-500/30",
                      else: "bg-white/5 border-transparent hover:bg-white/10 hover:border-white/10")}>
                  <div class={"relative flex items-center justify-center w-5 h-5 min-w-[1.25rem] rounded border transition-all duration-300 " <>
                      if(checked?, do: "bg-emerald-500 border-emerald-500", else: "border-white/30 bg-white/5")}>
                    <input
                      type="checkbox"
                      name={field_name <> "[]"}
                      value={item["label"]}
                      checked={checked?}
                      class="absolute opacity-0 w-full h-full cursor-pointer"
                    />
                    <!-- Custom Checkmark Icon -->
                    <%= if checked? do %>
                      <svg
                        class="w-3.5 h-3.5 text-white drop-shadow-sm"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="3"
                          d="M5 13l4 4L19 7"
                        >
                        </path>
                      </svg>
                    <% end %>
                  </div>

                  <span class={"text-sm leading-tight flex-1 transition-colors " <> if(checked?, do: "text-white font-medium", else: "text-white/70 group-hover:text-white")}>
                    {item["label"]}
                  </span>
                </label>
              <% end %>
            </div>
          <% else %>
            <% checked? = is_checked?(form_data, field_name, "on") %>
            <label class={"flex items-center gap-3 cursor-pointer select-none group p-3 rounded-xl transition-all duration-300 border " <>
                   if(checked?,
                      do: "bg-emerald-500/20 border-emerald-500/50 shadow-[0_0_20px_rgba(16,185,129,0.15)] ring-1 ring-emerald-500/30",
                      else: "bg-white/5 border-transparent hover:bg-white/10 hover:border-white/10")}>
              <div class={"relative flex items-center justify-center w-5 h-5 rounded border transition-all duration-300 " <>
                      if(checked?, do: "bg-emerald-500 border-emerald-500", else: "border-white/30 bg-white/5")}>
                <input
                  type="checkbox"
                  name={field_name}
                  value="on"
                  checked={checked?}
                  class="absolute opacity-0 w-full h-full cursor-pointer"
                />
                <%= if checked? do %>
                  <svg
                    class="w-3.5 h-3.5 text-white drop-shadow-sm"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="3"
                      d="M5 13l4 4L19 7"
                    >
                    </path>
                  </svg>
                <% end %>
              </div>

              <span class={"text-sm leading-tight flex-1 transition-colors " <> if(checked?, do: "text-white font-medium", else: "text-white/70 group-hover:text-white")}>
                Sim / Confirmar
              </span>
            </label>
          <% end %>
        <% "radio" -> %>
          <% items = (@field.options || %{})["items"] || [] %>
          <div class="space-y-3">
            <%= for item <- items do %>
              <% checked? = is_radio_checked?(form_data, field_name, item["label"]) %>
              <label class={"flex items-center gap-3 cursor-pointer select-none group p-3 rounded-xl transition-all duration-300 border " <>
                   if(checked?,
                      do: "bg-emerald-500/20 border-emerald-500/50 shadow-[0_0_20px_rgba(16,185,129,0.15)] ring-1 ring-emerald-500/30",
                      else: "bg-white/5 border-transparent hover:bg-white/10 hover:border-white/10")}>
                <div class={"relative flex items-center justify-center w-5 h-5 min-w-[1.25rem] rounded-full border transition-all duration-300 " <>
                      if(checked?, do: "border-emerald-500", else: "border-white/30 bg-white/5")}>
                  <input
                    type="radio"
                    name={field_name}
                    value={item["label"]}
                    checked={checked?}
                    class="absolute opacity-0 w-full h-full cursor-pointer"
                  />
                  <%= if checked? do %>
                    <div class="w-2.5 h-2.5 bg-emerald-500 rounded-full shadow-[0_0_10px_rgba(16,185,129,0.8)]">
                    </div>
                  <% end %>
                </div>

                <span class={"text-sm leading-tight flex-1 transition-colors " <> if(checked?, do: "text-white font-medium", else: "text-white/70 group-hover:text-white")}>
                  {item["label"]}
                </span>
              </label>
            <% end %>
          </div>
        <% "file" -> %>
          <label
            phx-drop-target={@uploads[String.to_atom("field_#{@field.id}")].ref}
            class="cursor-pointer block border-2 border-dashed border-white/10 rounded-xl p-6 text-center hover:border-blue-500/30 transition-colors bg-black/10 hover:bg-white/5"
          >
            <div class="mb-4 pointer-events-none">
              <.live_file_input
                upload={@uploads[String.to_atom("field_#{@field.id}")]}
                class="hidden"
              />
              <div class="text-white/40 text-sm font-medium">
                <span class="text-blue-400">Clique para selecionar</span> ou arraste arquivos
              </div>
            </div>
            
    <!-- Preview of selected files -->
            <div class="grid grid-cols-2 gap-2 mt-4 pointer-events-auto">
              <%= for entry <- @uploads[String.to_atom("field_#{@field.id}")].entries do %>
                <div class="relative bg-white/5 rounded-lg p-2 flex items-center gap-2 overflow-hidden border border-white/10">
                  <div class="text-white text-xs truncate flex-1">{entry.client_name}</div>
                  <div class="text-white/40 text-xs">{entry.progress}%</div>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    phx-value-upload={field_name}
                    class="text-red-400 hover:text-red-300 p-1 hover:bg-white/10 rounded"
                  >
                    &times;
                  </button>
                </div>
              <% end %>
            </div>
          </label>
        <% _ -> %>
          <div class="text-red-400 text-xs">Tipo desconhecido: {@field.type}</div>
      <% end %>
    </div>
    """
  end
end
