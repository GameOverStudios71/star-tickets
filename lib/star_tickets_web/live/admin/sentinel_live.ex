defmodule StarTicketsWeb.Admin.SentinelLive do
  use StarTicketsWeb, :live_view
  alias StarTickets.Sentinel.Overseer
  alias StarTickets.Audit.Actions
  alias Phoenix.PubSub

  alias StarTicketsWeb.ImpersonationHelpers

  import StarTicketsWeb.Components.AuditActionsFilter

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    if connected?(socket) do
      # Register as observer - this activates the Sentinel
      Overseer.register_observer(self())

      # Subscribe to Sentinel events
      PubSub.subscribe(StarTickets.PubSub, "sentinel_events")
      PubSub.subscribe(StarTickets.PubSub, "system:presence")
    end

    # Get initial state from Overseer
    initial_state = Overseer.get_state()
    sentinel_active = Overseer.active?()

    initial_presence =
      if connected?(socket) do
        StarTicketsWeb.Presence.list("system:presence")
      else
        %{}
      end

    {:ok,
     socket
     |> assign(impersonation_assigns)
     |> assign(:projections, initial_state.projections)
     |> assign(:anomalies, initial_state.anomalies)
     |> assign(:recent_logs, initial_state.recent_logs)
     |> assign(:presences, initial_presence)
     |> assign(:ingestion_collapsed, true)
     |> assign(:selected_actions, Actions.live_monitoring_defaults())
     |> assign(:sentinel_active, sentinel_active)
     |> assign(:page_title, "Sentinel AI")}
  end

  def terminate(_reason, socket) do
    # Unregister as observer - this may deactivate the Sentinel if no observers remain
    if socket.assigns[:sentinel_active] do
      Overseer.unregister_observer(self())
    end

    :ok
  end

  def handle_info(%{topic: "system:presence", event: "presence_diff", payload: diff}, socket) do
    {:noreply, assign(socket, :presences, sync_presence(socket.assigns.presences, diff))}
  end

  def handle_info({:sentinel_update, state}, socket) do
    {:noreply,
     socket
     |> assign(:projections, state.projections)
     |> assign(:anomalies, state.anomalies)
     |> assign(:recent_logs, state.recent_logs)}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen text-white font-mono p-4 flex flex-col pt-20">
      <.app_header
        show_home={true}
        current_scope={@current_scope}
        client_name={@client_name}
        establishments={@establishments}
        users={@users}
        impersonating={@impersonating}
      >
        <:left>
          <div class="flex items-center gap-4">
            <div class="relative w-10 h-10 flex items-center justify-center">
              <div class="absolute inset-0 bg-cyan-500 blur-xl opacity-20 animate-pulse"></div>
              <div class="relative w-full h-full border-2 border-cyan-400 rounded-full flex items-center justify-center bg-black">
                <i class="fa-solid fa-eye text-cyan-400 text-sm animate-pulse"></i>
              </div>
            </div>
            <div>
              <h1 class="text-xl font-bold tracking-widest text-cyan-400">SENTINEL_AI</h1>
              <p class="text-[0.6rem] text-cyan-700 uppercase tracking-[0.3em] hidden md:block">
                System Monitoring
              </p>
            </div>
          </div>
        </:left>

        <:right>
          <div class="flex gap-4 text-xs mr-4">
            <div class="flex flex-col items-end">
              <span class="text-cyan-700 font-bold text-[0.6rem]">STATUS</span>
              <%= if @sentinel_active do %>
                <span class="text-emerald-400 font-bold flex items-center gap-1">
                  <span class="w-2 h-2 bg-emerald-400 rounded-full animate-pulse"></span> ACTIVE
                </span>
              <% else %>
                <span class="text-gray-500 font-bold flex items-center gap-1">
                  <span class="w-2 h-2 bg-gray-500 rounded-full"></span> STANDBY
                </span>
              <% end %>
            </div>
            <div class="flex flex-col items-end">
              <span class="text-cyan-700 font-bold text-[0.6rem]">OBSERVERS</span>
              <span class="text-white font-mono">{if @sentinel_active, do: "1+", else: "0"}</span>
            </div>
          </div>
        </:right>
      </.app_header>
      
    <!-- Connectivity Monitor & Operational Flow -->
      <% connected = group_presences(@presences) %>
      
    <!-- Operational Flow Pipeline -->
      <% flow_status = check_operational_flow(connected) %>
      <div class="mb-6 mt-6 bg-black/30 backdrop-blur-md border border-white/10 rounded-xl p-6 shadow-2xl">
        <h2 class="text-cyan-600 font-bold uppercase tracking-widest mb-4 flex items-center gap-2 text-sm">
          <i class="fa-solid fa-code-branch"></i> Operational Flow
        </h2>

        <div class="flex items-center justify-between relative">
          <!-- Connector Line -->
          <div class="absolute top-1/2 left-0 w-full h-0.5 bg-cyan-900/30 -z-0"></div>
          
    <!-- Step 1: Totem -->
          <div class={"relative z-10 flex flex-col items-center gap-2 #{if flow_status.totem == :ok, do: "opacity-100", else: "opacity-100"}"}>
            <div class={"w-10 h-10 rounded-full flex items-center justify-center border-2 transition-all duration-500 " <>
               if(flow_status.totem == :ok,
                  do: "bg-cyan-950 border-cyan-500 text-cyan-400 shadow-[0_0_15px_rgba(6,182,212,0.5)]",
                  else: "bg-red-950 border-red-500 text-red-400 animate-pulse shadow-[0_0_15px_rgba(239,68,68,0.5)]")
             }>
              <i class="fa-solid fa-tablet-screen-button"></i>
            </div>
            <div class="text-[10px] font-bold uppercase tracking-wider bg-black/80 px-2 py-0.5 rounded border border-white/10">
              Totem
            </div>
            <%= if flow_status.totem != :ok do %>
              <div class="absolute -bottom-6 text-[9px] text-red-400 font-bold whitespace-nowrap bg-black/90 px-2 py-0.5 rounded border border-red-500/30">
                ⚠️ No Active Totems
              </div>
            <% end %>
          </div>
          
    <!-- Step 2: Printer -->
          <div class="relative z-10 flex flex-col items-center gap-2">
            <div class={"w-8 h-8 rounded-full flex items-center justify-center border-2 transition-all duration-500 " <>
               if(flow_status.printer == :ok,
                  do: "bg-cyan-900/50 border-cyan-500/50 text-cyan-400",
                  else: "bg-red-950 border-red-500 text-red-400 animate-pulse")
             }>
              <i class="fa-solid fa-print text-xs"></i>
            </div>
            <div class="text-[9px] opacity-60 bg-black/80 px-2 py-0.5 rounded">Printer</div>
            <%= if flow_status.printer != :ok do %>
              <div class="absolute -bottom-6 text-[9px] text-red-400 font-bold whitespace-nowrap bg-black/90 px-2 py-0.5 rounded border border-red-500/30">
                ⚠️ Printer Error
              </div>
            <% end %>
          </div>
          
    <!-- Step 3: Reception -->
          <div class="relative z-10 flex flex-col items-center gap-2">
            <div class={"w-10 h-10 rounded-full flex items-center justify-center border-2 transition-all duration-500 " <>
               if(flow_status.reception == :ok,
                  do: "bg-purple-950 border-purple-500 text-purple-400 shadow-[0_0_15px_rgba(168,85,247,0.5)]",
                  else: "bg-red-950 border-red-500 text-red-400 animate-pulse shadow-[0_0_15px_rgba(239,68,68,0.5)]")
             }>
              <i class="fa-solid fa-desktop"></i>
            </div>
            <div class="text-[10px] font-bold uppercase tracking-wider bg-black/80 px-2 py-0.5 rounded border border-white/10">
              Reception
            </div>
            <%= if flow_status.reception != :ok do %>
              <div class="absolute -bottom-6 text-[9px] text-red-400 font-bold whitespace-nowrap bg-black/90 px-2 py-0.5 rounded border border-red-500/30">
                ⚠️ No Receptionists
              </div>
            <% end %>
          </div>
          
    <!-- Step 4: TV -->
          <div class="relative z-10 flex flex-col items-center gap-2">
            <div class={"w-10 h-10 rounded-full flex items-center justify-center border-2 transition-all duration-500 " <>
               if(flow_status.tv == :ok,
                  do: "bg-emerald-950 border-emerald-500 text-emerald-400 shadow-[0_0_15px_rgba(16,185,129,0.5)]",
                  else: "bg-red-950 border-red-500 text-red-400 animate-pulse shadow-[0_0_15px_rgba(239,68,68,0.5)]")
             }>
              <i class="fa-solid fa-tv"></i>
            </div>
            <div class="text-[10px] font-bold uppercase tracking-wider bg-black/80 px-2 py-0.5 rounded border border-white/10">
              TV Panels
            </div>
            <%= if flow_status.tv != :ok do %>
              <div class="absolute -bottom-6 text-[9px] text-red-400 font-bold whitespace-nowrap bg-black/90 px-2 py-0.5 rounded border border-red-500/30">
                ⚠️ No Active Scrn
              </div>
            <% end %>
          </div>
          
    <!-- Step 5: Professionals -->
          <div class="relative z-10 flex flex-col items-center gap-2">
            <div class={"w-10 h-10 rounded-full flex items-center justify-center border-2 transition-all duration-500 " <>
               if(flow_status.professional == :ok,
                  do: "bg-emerald-950 border-emerald-500 text-emerald-400 shadow-[0_0_15px_rgba(16,185,129,0.5)]",
                  else: "bg-red-950 border-red-500 text-red-400 animate-pulse shadow-[0_0_15px_rgba(239,68,68,0.5)]")
             }>
              <i class="fa-solid fa-user-doctor"></i>
            </div>
            <div class="text-[10px] font-bold uppercase tracking-wider bg-black/80 px-2 py-0.5 rounded border border-white/10">
              Medical
            </div>
            <%= if flow_status.professional != :ok do %>
              <div class="absolute -bottom-6 text-[9px] text-red-400 font-bold whitespace-nowrap bg-black/90 px-2 py-0.5 rounded border border-red-500/30">
                {if flow_status.professional == :no_room,
                  do: "⚠️ Staff Not in Room",
                  else: "⚠️ No Active Staff"}
              </div>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Connectivity Monitor -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <!-- Smart TVs -->
        <div class="bg-black/30 backdrop-blur-md border border-white/10 rounded-xl p-4 relative overflow-hidden group hover:border-cyan-500/50 transition-all shadow-lg">
          <div class="absolute inset-0 bg-cyan-500/5 group-hover:bg-cyan-500/10 transition-colors">
          </div>
          <div class="flex justify-between items-center mb-3 relative z-10">
            <h3 class="font-bold text-cyan-400 uppercase tracking-widest text-xs flex items-center gap-2">
              <i class="fa-solid fa-tv"></i> Smart TVs
            </h3>
            <span class="bg-cyan-900/50 text-cyan-300 px-2 py-0.5 rounded text-xs font-bold">
              {length(connected.tvs)}
            </span>
          </div>
          <div class="space-y-2 max-h-32 overflow-y-auto custom-scrollbar relative z-10">
            <%= for tv <- connected.tvs do %>
              <div class="flex items-center justify-between text-xs bg-black/40 p-2 rounded border border-white/5">
                <div class="flex flex-col">
                  <span class="text-white/80 font-bold">TV #{String.slice(tv.id, 0, 4)}</span>
                  <span class="text-[9px] text-white/40">ID: {String.slice(tv.id, 0, 8)}...</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <span class="text-[9px] opacity-50 font-mono">{format_duration(tv.online_at)}</span>
                  <span class="w-2 h-2 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.8)] animate-pulse">
                  </span>
                </div>
              </div>
            <% end %>
            <%= if Enum.empty?(connected.tvs) do %>
              <div class="text-center py-4 text-white/20 text-xs italic">Offline</div>
            <% end %>
          </div>
        </div>
        
    <!-- Totems -->
        <div class="bg-black/30 backdrop-blur-md border border-white/10 rounded-xl p-4 relative overflow-hidden group hover:border-amber-500/50 transition-all shadow-lg">
          <div class="absolute inset-0 bg-amber-500/5 group-hover:bg-amber-500/10 transition-colors">
          </div>
          <div class="flex justify-between items-center mb-3 relative z-10">
            <h3 class="font-bold text-amber-400 uppercase tracking-widest text-xs flex items-center gap-2">
              <i class="fa-solid fa-tablet-screen-button"></i> Totems
            </h3>
            <span class="bg-amber-900/50 text-amber-300 px-2 py-0.5 rounded text-xs font-bold">
              {length(connected.totems)}
            </span>
          </div>
          <div class="space-y-2 max-h-32 overflow-y-auto custom-scrollbar relative z-10">
            <%= for totem <- connected.totems do %>
              <div class="flex items-center justify-between text-xs bg-black/40 p-2 rounded border border-white/5">
                <div class="flex flex-col">
                  <span class="text-white/80 font-bold">Totem #{String.slice(totem.id, 0, 4)}</span>
                  <span class="text-[9px] text-white/40">ID: {String.slice(totem.id, 0, 8)}...</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <span class="text-[9px] opacity-50 font-mono">
                    {format_duration(totem.online_at)}
                  </span>
                  <span class="w-2 h-2 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.8)] animate-pulse">
                  </span>
                </div>
              </div>
            <% end %>
            <%= if Enum.empty?(connected.totems) do %>
              <div class="text-center py-4 text-white/20 text-xs italic">Offline</div>
            <% end %>
          </div>
        </div>
        
    <!-- Reception -->
        <div class="bg-black/30 backdrop-blur-md border border-white/10 rounded-xl p-4 relative overflow-hidden group hover:border-purple-500/50 transition-all shadow-lg">
          <div class="absolute inset-0 bg-purple-500/5 group-hover:bg-purple-500/10 transition-colors">
          </div>
          <div class="flex justify-between items-center mb-3 relative z-10">
            <h3 class="font-bold text-purple-400 uppercase tracking-widest text-xs flex items-center gap-2">
              <i class="fa-solid fa-desktop"></i> Reception
            </h3>
            <span class="bg-purple-900/50 text-purple-300 px-2 py-0.5 rounded text-xs font-bold">
              {length(connected.reception)}
            </span>
          </div>
          <div class="space-y-2 max-h-32 overflow-y-auto custom-scrollbar relative z-10">
            <%= for user <- connected.reception do %>
              <div class="flex items-center justify-between text-xs bg-black/40 p-2 rounded border border-white/5">
                <div class="flex flex-col">
                  <span class="text-white/80 font-bold truncate max-w-[120px]">{user.name}</span>
                  <span class="text-[9px] text-white/40 truncate max-w-[120px]">{user.email}</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <span class="text-[9px] opacity-50 font-mono">
                    {format_duration(user.online_at)}
                  </span>
                  <span class="w-2 h-2 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.8)] animate-pulse">
                  </span>
                </div>
              </div>
            <% end %>
            <%= if Enum.empty?(connected.reception) do %>
              <div class="text-center py-4 text-white/20 text-xs italic">No active staff</div>
            <% end %>
          </div>
        </div>
        
    <!-- Professionals -->
        <div class="bg-black/30 backdrop-blur-md border border-white/10 rounded-xl p-4 relative overflow-hidden group hover:border-emerald-500/50 transition-all shadow-lg">
          <div class="absolute inset-0 bg-emerald-500/5 group-hover:bg-emerald-500/10 transition-colors">
          </div>
          <div class="flex justify-between items-center mb-3 relative z-10">
            <h3 class="font-bold text-emerald-400 uppercase tracking-widest text-xs flex items-center gap-2">
              <i class="fa-solid fa-user-doctor"></i> Professionals
            </h3>
            <span class="bg-emerald-900/50 text-emerald-300 px-2 py-0.5 rounded text-xs font-bold">
              {length(connected.professional)}
            </span>
          </div>
          <div class="space-y-2 max-h-32 overflow-y-auto custom-scrollbar relative z-10">
            <%= for user <- connected.professional do %>
              <div class="flex items-center justify-between text-xs bg-black/40 p-2 rounded border border-white/5">
                <div class="flex flex-col">
                  <span class="text-white/80 font-bold truncate max-w-[120px]">{user.name}</span>
                  <span class="text-[9px] text-white/40 truncate max-w-[120px]">{user.email}</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <span class="text-[9px] opacity-50 font-mono">
                    {format_duration(user.online_at)}
                  </span>
                  <span class="w-2 h-2 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.8)] animate-pulse">
                  </span>
                </div>
              </div>
            <% end %>
            <%= if Enum.empty?(connected.professional) do %>
              <div class="text-center py-4 text-white/20 text-xs italic">No active staff</div>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Live Ingestion Filter -->
      <div class="mb-4">
        <.live_ingestion_filter
          id="sentinel-ingestion-filter"
          title="Live Ingestion Filters"
          selected_actions={@selected_actions}
          collapsed={@ingestion_collapsed}
        />
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-4 gap-6 h-[calc(100vh-220px)]">
        
    <!-- Left Column: Projections -->
        <div class="lg:col-span-3 flex flex-col gap-6">
          
    <!-- Anomalies (Errors) -->
          <%= if length(@anomalies) > 0 do %>
            <div class="border border-red-500/50 bg-red-950/20 backdrop-blur-md rounded-xl p-4 relative overflow-hidden shadow-[0_0_30px_rgba(239,68,68,0.2)]">
              <div class="absolute inset-0 bg-red-500/5 animate-pulse"></div>
              <h2 class="text-red-500 font-bold uppercase tracking-widest mb-4 flex items-center gap-2 relative z-10">
                <i class="fa-solid fa-triangle-exclamation"></i>
                Detected Anomalies
                <span class="text-xs font-normal text-red-400/70">Click to expand details</span>
              </h2>
              <div class="grid grid-cols-1 gap-2 relative z-10 max-h-60 overflow-y-auto custom-scrollbar">
                <%= for {error, idx} <- Enum.with_index(Enum.take(@anomalies, 10)) do %>
                  <details class="group bg-red-900/40 rounded border border-red-500/30">
                    <summary class="p-3 cursor-pointer list-none flex items-start gap-3 hover:bg-red-800/40 transition-colors">
                      <i class="fa-solid fa-bug text-red-400 mt-0.5"></i>
                      <div class="flex-1">
                        <p class="text-xs text-red-200 font-bold">{to_string(error.action)}</p>
                        <p class="text-[10px] text-red-300/70">
                          {Calendar.strftime(error.inserted_at, "%H:%M:%S")} · {error.resource_type}
                        </p>
                      </div>
                      <i class="fa-solid fa-chevron-down text-red-400/50 group-open:rotate-180 transition-transform text-xs">
                      </i>
                    </summary>
                    <div class="p-3 border-t border-red-500/20 bg-black/40">
                      <div class="flex justify-between items-center mb-2">
                        <span class="text-[10px] text-red-400 uppercase font-bold">
                          Full JSON (Copy for debugging)
                        </span>
                        <div class="flex gap-2">
                          <button
                            id={"copy-anomaly-#{idx}"}
                            phx-hook="DebounceSubmit"
                            phx-click="copy_anomaly_json"
                            phx-value-idx={idx}
                            class="text-[10px] bg-red-500/20 hover:bg-red-500/40 text-red-300 px-2 py-1 rounded transition-colors"
                          >
                            <i class="fa-solid fa-copy mr-1"></i> Copy
                          </button>
                          <button
                            id={"dismiss-anomaly-#{idx}"}
                            phx-hook="DebounceSubmit"
                            phx-click="dismiss_anomaly"
                            phx-value-idx={idx}
                            class="text-[10px] bg-emerald-500/20 hover:bg-emerald-500/40 text-emerald-300 px-2 py-1 rounded transition-colors"
                          >
                            <i class="fa-solid fa-check mr-1"></i> Corrected
                          </button>
                        </div>
                      </div>
                      <pre class="text-[9px] text-red-200/80 bg-black/60 p-2 rounded overflow-x-auto max-h-40 overflow-y-auto whitespace-pre-wrap break-all font-mono custom-scrollbar">{Jason.encode!(format_anomaly_for_json(error), pretty: true)}</pre>
                    </div>
                  </details>
                <% end %>
              </div>
            </div>
          <% end %>
          
    <!-- Projections Grid -->
          <div class="bg-black/30 backdrop-blur-md border border-white/10 rounded-xl p-6 flex-1 overflow-hidden flex flex-col shadow-2xl">
            <h2 class="text-cyan-600 font-bold uppercase tracking-widest mb-4 flex items-center gap-2 text-sm">
              <i class="fa-solid fa-timeline"></i>
              Active Projections
              <span class="bg-cyan-900/50 text-cyan-300 px-2 py-0.5 rounded text-xs">
                {length(@projections)}
              </span>
            </h2>

            <div class="flex-1 overflow-y-auto max-h-[600px] grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 content-start pr-2 custom-scrollbar">
              <%= for proj <- @projections do %>
                <div class={"border rounded-lg p-4 relative overflow-hidden transition-all duration-500 min-h-[180px] #{status_classes(proj)}"}>
                  <div class="flex justify-between items-start mb-2 relative z-10">
                    <span class="text-[10px] uppercase font-bold tracking-wider opacity-70">
                      ID: {String.slice(proj.id, 0, 8)}
                    </span>
                    <span class="text-xs font-bold px-2 py-0.5 rounded bg-black/30 backdrop-blur-sm">
                      {proj.status}
                    </span>
                  </div>

                  <h3 class="font-bold text-sm mb-1 relative z-10">{proj.name}</h3>
                  <p class="text-xs opacity-70 mb-3 relative z-10">{proj.description}</p>
                  
    <!-- Ticket Details Section -->
                  <%= if proj.trigger_event.details do %>
                    <div class="text-[10px] mb-3 relative z-10 space-y-1 bg-black/20 rounded p-2">
                      <%= if proj.trigger_event.details["customer_name"] || proj.trigger_event.details[:customer_name] do %>
                        <div class="flex items-center gap-1">
                          <i class="fa-solid fa-user opacity-50 w-3"></i>
                          <span class="opacity-70">Cliente:</span>
                          <span class="font-bold">
                            {proj.trigger_event.details["customer_name"] ||
                              proj.trigger_event.details[:customer_name]}
                          </span>
                        </div>
                      <% end %>
                      <%= if proj.trigger_event.details["code"] || proj.trigger_event.details[:code] || proj.trigger_event.details["ticket_code"] do %>
                        <div class="flex items-center gap-1">
                          <i class="fa-solid fa-ticket opacity-50 w-3"></i>
                          <span class="opacity-70">Senha:</span>
                          <span class="font-bold font-mono">
                            {proj.trigger_event.details["code"] || proj.trigger_event.details[:code] ||
                              proj.trigger_event.details["ticket_code"]}
                          </span>
                        </div>
                      <% end %>
                      <%= if proj.trigger_event.details["services"] do %>
                        <div class="flex items-start gap-1">
                          <i class="fa-solid fa-list-check opacity-50 w-3 mt-0.5"></i>
                          <span class="opacity-70">Serviços:</span>
                          <span class="font-bold">{proj.trigger_event.details["services"]}</span>
                        </div>
                      <% end %>
                      <%= if proj.trigger_event.details["reception_user"] do %>
                        <div class="flex items-center gap-1">
                          <i class="fa-solid fa-desktop opacity-50 w-3"></i>
                          <span class="opacity-70">Recepção:</span>
                          <span class="font-bold">
                            {proj.trigger_event.details["reception_user"]}
                          </span>
                        </div>
                      <% end %>
                      <%= if proj.trigger_event.details["professional_user"] do %>
                        <div class="flex items-center gap-1">
                          <i class="fa-solid fa-user-doctor opacity-50 w-3"></i>
                          <span class="opacity-70">Profissional:</span>
                          <span class="font-bold">
                            {proj.trigger_event.details["professional_user"]}
                          </span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <div class="flex items-center gap-2 text-[10px] relative z-10">
                    <div class="flex flex-col">
                      <span class="opacity-50 uppercase">Trigger</span>
                      <span class="font-bold">{proj.trigger_event.action}</span>
                    </div>
                    <i class="fa-solid fa-arrow-right opacity-50"></i>
                    <div class="flex flex-col">
                      <span class="opacity-50 uppercase">Waiting For</span>
                      <span class="font-bold">{proj.expected_action}</span>
                    </div>
                  </div>

                  <%= if proj.status == :pending do %>
                    <div class="mt-4 w-full bg-black/30 h-1 rounded-full overflow-hidden relative z-10">
                      <div class="h-full bg-current opacity-50 w-full animate-progress origin-left">
                      </div>
                    </div>
                    <div class="text-[9px] text-right mt-1 opacity-50 relative z-10">
                      Expires: {Calendar.strftime(proj.deadline, "%H:%M:%S")}
                    </div>
                  <% end %>
                  
    <!-- Background Icon -->
                  <i class={"fa-solid #{status_icon(proj.status)} absolute -bottom-4 -right-4 text-8xl opacity-5 pointer-events-none"}>
                  </i>
                </div>
              <% end %>

              <%= if Enum.empty?(@projections) do %>
                <div class="col-span-full flex flex-col items-center justify-center text-cyan-900 py-12">
                  <i class="fa-solid fa-brain text-4xl mb-2 animate-pulse"></i>
                  <p>No active projections. Waiting for events...</p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        
    <!-- Right Column: Live Feed -->
        <div class="lg:col-span-1 flex flex-col h-full gap-4">
          <div class="st-card st-acrylic p-4 flex-1 flex flex-col h-full overflow-hidden shadow-2xl">
            <h2 class="text-cyan-600 font-bold uppercase tracking-widest mb-4 flex items-center gap-2 text-sm shrink-0 mt-4">
              <i class="fa-solid fa-satellite-dish animate-pulse"></i> Live Ingestion
            </h2>

            <div class="flex-1 overflow-y-auto space-y-2 pr-2 custom-scrollbar min-h-0">
              <%= for log <- Enum.filter(@recent_logs, & &1.action in @selected_actions) do %>
                <div class="border-l-2 border-cyan-800 pl-3 py-1 opacity-70 hover:opacity-100 hover:bg-cyan-900/10 transition-all">
                  <div class="flex justify-between text-[10px] text-cyan-600 mb-0.5">
                    <span>{Calendar.strftime(log.inserted_at, "%H:%M:%S")}</span>
                    <span>#{log.resource_id}</span>
                  </div>
                  <div class="text-cyan-300 font-bold truncate">
                    {log.action}
                  </div>
                  <div class="text-cyan-500/50 truncate text-[10px]">
                    {log.user && log.user.email}
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("toggle_ingestion_panel", _, socket) do
    {:noreply, update(socket, :ingestion_collapsed, &(!&1))}
  end

  def handle_event("toggle_action_filter", %{"action" => action}, socket) do
    selected = socket.assigns.selected_actions

    new_selected =
      if action in selected do
        List.delete(selected, action)
      else
        [action | selected]
      end

    {:noreply, assign(socket, :selected_actions, new_selected)}
  end

  def handle_event("select_all_actions", _, socket) do
    {:noreply, assign(socket, :selected_actions, Actions.all())}
  end

  def handle_event("clear_all_actions", _, socket) do
    {:noreply, assign(socket, :selected_actions, [])}
  end

  def handle_event("reset_default_actions", _, socket) do
    {:noreply, assign(socket, :selected_actions, Actions.live_monitoring_defaults())}
  end

  def handle_event("copy_anomaly_json", %{"idx" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    anomalies = socket.assigns.anomalies

    if idx < length(anomalies) do
      error = Enum.at(anomalies, idx)
      json = Jason.encode!(format_anomaly_for_json(error), pretty: true)

      # Push JSON to clipboard via JS hook
      {:noreply, push_event(socket, "copy_to_clipboard", %{text: json})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("dismiss_anomaly", %{"idx" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    anomalies = socket.assigns.anomalies

    if idx < length(anomalies) do
      # Remove the anomaly from the local list
      new_anomalies = List.delete_at(anomalies, idx)

      # Also update the Overseer state so it stays in sync
      StarTickets.Sentinel.Overseer.dismiss_anomaly(idx)

      {:noreply, assign(socket, :anomalies, new_anomalies)}
    else
      {:noreply, socket}
    end
  end

  defp status_classes(projection) when is_map(projection) do
    status = projection.status
    expected_action = projection.expected_action

    # WebCheckin failures should be yellow (warning), not red (error)
    is_webcheckin = expected_action in ["WEBCHECKIN_STARTED", "WEBCHECKIN_COMPLETED"]

    cond do
      status == :pending -> "bg-cyan-950/30 border-cyan-500/30 text-cyan-100"
      status == :verified -> "bg-emerald-950/30 border-emerald-500/30 text-emerald-100"
      status == :failed and is_webcheckin -> "bg-amber-950/30 border-amber-500/30 text-amber-100"
      status == :failed -> "bg-red-950/30 border-red-500/30 text-red-100"
      true -> "bg-cyan-950/30 border-cyan-500/30 text-cyan-100"
    end
  end

  defp status_icon(:pending), do: "fa-hourglass-start"
  defp status_icon(:verified), do: "fa-check-circle"
  defp status_icon(:failed), do: "fa-circle-xmark"

  defp format_anomaly_for_json(error) do
    %{
      id: error[:id] || error.id,
      action: to_string(error.action),
      resource_type: error.resource_type,
      resource_id: error.resource_id,
      details: error.details,
      metadata: error[:metadata] || %{},
      timestamp: error.inserted_at,
      user: if(error[:user], do: %{id: error.user.id, email: error.user.email}, else: nil)
    }
  end

  defp group_presences(presences) do
    Enum.reduce(presences, %{tvs: [], totems: [], reception: [], professional: []}, fn {_key,
                                                                                        data},
                                                                                       acc ->
      meta = List.first(data.metas)
      type = Map.get(meta, :type) || Map.get(meta, "type")

      case type do
        "tv" -> Map.update!(acc, :tvs, &[meta | &1])
        "totem" -> Map.update!(acc, :totems, &[meta | &1])
        "reception" -> Map.update!(acc, :reception, &[meta | &1])
        "professional" -> Map.update!(acc, :professional, &[meta | &1])
        _ -> acc
      end
    end)
  end

  defp format_duration(start_time) do
    now = System.system_time(:second)
    diff = now - start_time

    cond do
      diff < 60 -> "#{diff}s"
      diff < 3600 -> "#{div(diff, 60)}m"
      true -> "#{div(diff, 3600)}h"
    end
  end

  defp sync_presence(presences, %{joins: joins, leaves: leaves}) do
    presences
    |> Map.drop(Map.keys(leaves))
    |> Map.merge(joins)
  end

  defp check_operational_flow(connected) do
    # 1. Totem Status
    totem_ok = if Enum.any?(connected.totems), do: :ok, else: :error

    # 2. Printer Status (Check if any active totem has printer ok)
    # Using mock data added to TotemLive
    printer_ok =
      if totem_ok == :ok do
        if Enum.any?(connected.totems, fn t -> t[:printer_status] == "ok" end),
          do: :ok,
          else: :error
      else
        :error
      end

    # 3. Reception Status
    reception_ok = if Enum.any?(connected.reception), do: :ok, else: :error

    # 4. TV Status
    tv_ok = if Enum.any?(connected.tvs), do: :ok, else: :error

    # 5. Professional Status & Room Assignment
    professional_status =
      cond do
        Enum.empty?(connected.professional) ->
          :error

        # Check if at least one professional has a room_id assigned (not nil)
        !Enum.any?(connected.professional, fn p -> p[:room_id] && p[:room_id] != nil end) ->
          :no_room

        true ->
          :ok
      end

    %{
      totem: totem_ok,
      printer: printer_ok,
      reception: reception_ok,
      tv: tv_ok,
      professional: professional_status
    }
  end
end
