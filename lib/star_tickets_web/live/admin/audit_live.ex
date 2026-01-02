defmodule StarTicketsWeb.Admin.AuditLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Audit
  alias StarTickets.Accounts
  alias StarTicketsWeb.ImpersonationHelpers

  import StarTicketsWeb.Components.AuditActionsFilter

  def mount(params, session, socket) do
    if connected?(socket) do
      # Subscribe to ALL audit logs
      Audit.subscribe_to_logs()
    end

    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    # Initial pagination state
    page = String.to_integer(params["page"] || "1")
    page_size = 20

    # Initial load should use params
    initial_filters = %{
      "start_date" => params["start_date"],
      "end_date" => params["end_date"],
      "action" => params["action"],
      "user_id" => params["user_id"]
    }

    {logs, _} = load_logs(page, page_size, initial_filters)
    total_logs = Audit.count_logs(initial_filters)
    users = Accounts.list_users()

    audit_actions = StarTickets.Audit.Actions.all()

    {:ok,
     socket
     |> assign(impersonation_assigns)
     |> assign(:logs, logs)
     |> assign(:users, users)
     |> assign(:audit_actions, audit_actions)
     |> assign(:ingestion_collapsed, true)
     |> assign(:filter_form, to_form(initial_filters))
     |> assign(:filters, initial_filters)
     |> assign(:page, page)
     |> assign(:page_size, page_size)
     |> assign(:total_logs, total_logs)
     |> assign(:selected_log, nil)
     |> assign(:loading, false)}
  end

  def handle_params(params, _uri, socket) do
    page = String.to_integer(params["page"] || "1")

    # Merge query params with current filters if needed or just use params
    filters = %{
      "start_date" => params["start_date"],
      "end_date" => params["end_date"],
      "action" => params["action"] || socket.assigns[:filters]["action"],
      "user_id" => params["user_id"]
    }

    {logs, _} = load_logs(page, socket.assigns.page_size, filters)
    total = Audit.count_logs(filters)

    {:noreply,
     socket
     |> assign(:logs, logs)
     |> assign(:page, page)
     |> assign(:filters, filters)
     |> assign(:total_logs, total)
     |> assign(:selected_log, nil)}
  end

  def handle_info({:audit_log_created, log}, socket) do
    # Real-time updates only for first page
    if socket.assigns.page == 1 do
      updated_logs = [log | socket.assigns.logs] |> Enum.take(socket.assigns.page_size)
      {:noreply, assign(socket, :logs, updated_logs)}
    else
      # Maybe show a notification, but for now just ignore visual update
      {:noreply, socket}
    end
  end

  def handle_event("filter", params, socket) do
    # Reset to page 1 on filter change
    push_params =
      Map.take(params, ["start_date", "end_date", "action", "user_id"]) |> Map.put("page", 1)

    {:noreply, push_patch(socket, to: ~p"/admin/audit?#{push_params}")}
  end

  def handle_event("toggle_action_filter", %{"action" => action}, socket) do
    current_actions = socket.assigns.filters["action"] || ""
    current_list = String.split(current_actions, ",", trim: true)

    updated_list =
      if action in current_list do
        List.delete(current_list, action)
      else
        [action | current_list]
      end

    updated_actions = Enum.join(updated_list, ",")
    params = Map.put(socket.assigns.filters, "action", updated_actions) |> Map.put("page", 1)
    {:noreply, push_patch(socket, to: ~p"/admin/audit?#{params}")}
  end

  def handle_event("toggle_all_actions", _params, socket) do
    current_actions = socket.assigns.filters["action"] || ""
    current_list = String.split(current_actions, ",", trim: true)
    all_actions = socket.assigns.audit_actions

    # Logic: If all selects -> clear all. If some or none -> select all.
    # User request "Inverter Seleção" suggests a simplistic toggle or smart toggle.
    # Let's do: If current_list has items, flip them (remove them from all_actions).
    # But "Select All" / "Deselect All" is usually what people want.
    # Let's implement exact "Invert": Items selected become unselected, unselected become selected.

    updated_list =
      Enum.reduce(all_actions, [], fn action, acc ->
        if action in current_list do
          # Remove
          acc
        else
          # Add
          [action | acc]
        end
      end)

    updated_actions = Enum.join(updated_list, ",")
    params = Map.put(socket.assigns.filters, "action", updated_actions) |> Map.put("page", 1)
    {:noreply, push_patch(socket, to: ~p"/admin/audit?#{params}")}
  end

  def handle_event("toggle_ingestion_panel", _, socket) do
    {:noreply, update(socket, :ingestion_collapsed, &(!&1))}
  end

  def handle_event("select_all_actions", _, socket) do
    all_actions = StarTickets.Audit.Actions.all() |> Enum.join(",")
    params = Map.put(socket.assigns.filters, "action", all_actions) |> Map.put("page", 1)
    {:noreply, push_patch(socket, to: ~p"/admin/audit?#{params}")}
  end

  def handle_event("clear_all_actions", _, socket) do
    params = Map.put(socket.assigns.filters, "action", "") |> Map.put("page", 1)
    {:noreply, push_patch(socket, to: ~p"/admin/audit?#{params}")}
  end

  def handle_event("reset_default_actions", _, socket) do
    params = Map.put(socket.assigns.filters, "action", nil) |> Map.put("page", 1)
    {:noreply, push_patch(socket, to: ~p"/admin/audit?#{params}")}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    push_params = Map.merge(socket.assigns.filters, %{"page" => page})
    {:noreply, push_patch(socket, to: ~p"/admin/audit?#{push_params}")}
  end

  def handle_event("show_payload", %{"id" => id}, socket) do
    log = Enum.find(socket.assigns.logs, fn l -> to_string(l.id) == id end)
    {:noreply, assign(socket, :selected_log, log)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :selected_log, nil)}
  end

  def handle_event("clear_logs", _params, socket) do
    {count, _} = Audit.delete_logs_older_than(90)

    {:noreply,
     socket
     |> put_flash(:info, "#{count} logs antigos foram removidos com sucesso.")
     |> push_navigate(to: ~p"/admin/audit")}
  end

  defp load_logs(page, page_size, params) do
    filter_params = Map.put(params, "page", page) |> Map.put("page_size", page_size)
    logs = Audit.list_logs(filter_params)
    {logs, params}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-20">
      <.app_header
        title="Auditoria"
        show_home={true}
        current_scope={@current_scope}
        {assigns}
      />

      <div class="st-container m-4" style="margin-top: 0;">
        
    <!-- Filters -->
        <div class="st-card st-acrylic p-6 mb-8 rounded-2xl border border-white/10 mt-6">
          <form phx-change="filter" class="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
            <div class="form-group">
              <label class="block text-sm font-medium text-white/70 mb-1">Data Início</label>
              <input
                type="date"
                name="start_date"
                value={@filters["start_date"]}
                phx-debounce="300"
                class="st-input w-full bg-white/5 border-white/10 text-white rounded-lg"
              />
            </div>
            <div class="form-group">
              <label class="block text-sm font-medium text-white/70 mb-1">Data Fim</label>
              <input
                type="date"
                name="end_date"
                value={@filters["end_date"]}
                phx-debounce="300"
                class="st-input w-full bg-white/5 border-white/10 text-white rounded-lg"
              />
            </div>

            <div class="form-group md:col-span-2">
              <label class="block text-sm font-medium text-white/70 mb-1">Usuário</label>
              <select
                name="user_id"
                class="st-input w-full bg-white/5 border-white/10 text-white rounded-lg"
              >
                <option value="">Todos os usuários</option>
                <%= for user <- @users do %>
                  <option value={user.id} selected={@filters["user_id"] == to_string(user.id)}>
                    {user.name} ({user.email})
                  </option>
                <% end %>
              </select>
            </div>
            
    <!-- Multi-Action Checkbox Grid -->
            <div class="col-span-1 md:col-span-4 mt-2">
              <.live_ingestion_filter
                id="audit-actions-filter"
                title="Filtrar por Tipos de Ação"
                selected_actions={String.split(@filters["action"] || "", ",", trim: true)}
                collapsed={@ingestion_collapsed}
              />
            </div>
          </form>
        </div>
        
    <!-- Logs Table -->
        <div class="st-card st-acrylic rounded-2xl overflow-hidden border border-white/10">
          <div class="overflow-x-auto">
            <table class="w-full text-left border-collapse">
              <thead>
                <tr class="border-b border-white/10 bg-white/5 text-white/60 text-sm uppercase tracking-wider">
                  <th class="p-4 font-medium">Data/Hora</th>
                  <th class="p-4 font-medium">Ação</th>
                  <th class="p-4 font-medium">Quem?</th>
                  <th class="p-4 font-medium">Recurso</th>
                  <th class="p-4 font-medium">Detalhes</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-white/5">
                <%= for log <- @logs do %>
                  <tr class="hover:bg-white/5 transition-colors text-white/80">
                    <td class="p-4 whitespace-nowrap text-sm font-mono text-white/50">
                      {Calendar.strftime(log.inserted_at, "%d/%m/%Y %H:%M:%S")}
                    </td>
                    <td class="p-4">
                      <span class={"px-2 py-1 rounded text-xs font-bold #{audit_badge_color(log.action)}"}>
                        {log.action}
                      </span>
                    </td>
                    <td class="p-4">
                      <%= if log.user do %>
                        <div class="flex items-center gap-2">
                          <div class="w-6 h-6 rounded-full bg-indigo-500/30 flex items-center justify-center text-xs text-indigo-200">
                            {String.at(log.user.name || "?", 0)}
                          </div>
                          <span class="text-sm">{log.user.email}</span>
                        </div>
                      <% else %>
                        <span class="text-white/30 text-sm italic">Sistema/Anônimo</span>
                      <% end %>
                    </td>
                    <td class="p-4 text-sm text-white/60">
                      {log.resource_type} #{log.resource_id}
                    </td>
                    <td class="p-4">
                      <button
                        phx-click="show_payload"
                        phx-value-id={log.id}
                        class="text-xs text-blue-300 hover:text-blue-200 flex items-center gap-1 transition-colors"
                      >
                        <i class="fa-regular fa-eye"></i> Ver Payload
                      </button>
                    </td>
                  </tr>
                <% end %>
                <%= if Enum.empty?(@logs) do %>
                  <tr>
                    <td colspan="5" class="p-12 text-center text-white/30">
                      <div class="text-4xl mb-2">🔍</div>
                      <p>Nenhum log encontrado com os filtros atuais.</p>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          
    <!-- Pagination -->
          <div class="p-4 border-t border-white/10 flex items-center justify-between bg-white/5">
            <div class="text-sm text-white/50">
              Mostrando página <span class="font-bold text-white">{@page}</span>
              de <span class="font-bold text-white">{ceil(@total_logs / @page_size)}</span>
              (Total: {@total_logs} registros)
            </div>
            <div class="flex gap-2">
              <button
                phx-click="change_page"
                phx-value-page={@page - 1}
                disabled={@page <= 1}
                class="px-3 py-1 bg-white/5 hover:bg-white/10 disabled:opacity-30 disabled:cursor-not-allowed rounded text-white text-sm"
              >
                Anterior
              </button>
              <button
                phx-click="change_page"
                phx-value-page={@page + 1}
                disabled={@page * @page_size >= @total_logs}
                class="px-3 py-1 bg-white/5 hover:bg-white/10 disabled:opacity-30 disabled:cursor-not-allowed rounded text-white text-sm"
              >
                Próximo
              </button>
            </div>
          </div>
        </div>
      </div>
      <!-- JSON Payload Modal -->
      <.modal
        :if={@selected_log}
        id="payload-modal"
        show={!!@selected_log}
        transparent={true}
        on_cancel={JS.push("close_modal")}
      >
        <div class="st-card st-acrylic p-8 rounded-2xl border border-white/10 shadow-2xl relative overflow-hidden">
          <!-- Header -->
          <div class="flex items-center justify-between mb-6">
            <h3 class="font-bold text-xl text-white flex items-center gap-3">
              <div class="w-10 h-10 rounded-lg bg-blue-500/20 flex items-center justify-center border border-blue-500/30">
                <i class="fa-solid fa-code text-blue-300"></i>
              </div>
              Payload: {@selected_log.action}
            </h3>
            <button phx-click="close_modal" class="text-white/50 hover:text-white transition-colors">
              <i class="fa-solid fa-xmark text-xl"></i>
            </button>
          </div>

          <div class="space-y-6">
            <div>
              <div class="flex items-center gap-2 mb-2">
                <i class="fa-solid fa-list-ul text-emerald-400 text-xs"></i>
                <p class="text-xs font-bold text-white/50 uppercase tracking-widest">
                  Detalhes da Ação
                </p>
              </div>
              <div class="mockup-code bg-black/40 border border-white/5 text-xs text-left">
                <pre class="bg-transparent text-emerald-300" style="white-space: pre-wrap;"><code>{format_json(@selected_log.details)}</code></pre>
              </div>
            </div>

            <%= if @selected_log.metadata && map_size(@selected_log.metadata) > 0 do %>
              <details class="group">
                <summary class="flex items-center gap-2 mb-2 cursor-pointer list-none">
                  <i class="fa-solid fa-chevron-right text-xs text-white/30 group-open:rotate-90 transition-transform">
                  </i>
                  <i class="fa-solid fa-laptop-code text-sky-400 text-xs"></i>
                  <p class="text-xs font-bold text-white/50 uppercase tracking-widest">
                    Metadata (Device)
                  </p>
                </summary>
                <div class="mockup-code bg-black/40 border border-white/5 text-xs text-left">
                  <pre class="bg-transparent text-sky-300" style="white-space: pre-wrap;"><code>{format_json(@selected_log.metadata)}</code></pre>
                </div>
              </details>
            <% end %>
          </div>

          <div class="mt-8 flex justify-end">
            <button
              phx-click="close_modal"
              class="px-6 py-2 bg-white/10 hover:bg-white/20 text-white rounded-lg border border-white/10 transition-all font-medium"
            >
              Fechar
            </button>
          </div>
        </div>
      </.modal>
    </div>
    """
  end

  defp audit_badge_color(action) do
    cond do
      String.contains?(action, "ERROR") or String.contains?(action, "FAILED") ->
        "bg-red-500/20 text-red-300 border border-red-500/30"

      String.contains?(action, "DELETE") ->
        "bg-orange-500/20 text-orange-300 border border-orange-500/30"

      String.contains?(action, "CREATE") or String.contains?(action, "START") ->
        "bg-emerald-500/20 text-emerald-300 border border-emerald-500/30"

      String.contains?(action, "LOGIN") ->
        "bg-purple-500/20 text-purple-300 border border-purple-500/30"

      String.contains?(action, "TOTEM") ->
        "bg-cyan-500/20 text-cyan-300 border border-cyan-500/30"

      String.contains?(action, "TV") ->
        "bg-pink-500/20 text-pink-300 border border-pink-500/30"

      true ->
        "bg-slate-500/20 text-slate-300 border border-slate-500/30"
    end
  end

  defp format_json(data) do
    # Try to recursively parse strings that look like JSON
    processed_data =
      case data do
        map when is_map(map) ->
          Map.new(map, fn {k, v} -> {k, try_parse_json(v)} end)

        list when is_list(list) ->
          Enum.map(list, &try_parse_json/1)

        other ->
          other
      end

    Jason.encode!(processed_data, pretty: true)
  rescue
    _ -> inspect(data, pretty: true)
  end

  defp try_parse_json(value) when is_binary(value) do
    if String.starts_with?(value, "{") or String.starts_with?(value, "[") do
      case Jason.decode(value) do
        {:ok, decoded} -> decoded
        _ -> value
      end
    else
      value
    end
  end

  defp try_parse_json(value), do: value
end
