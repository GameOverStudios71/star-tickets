defmodule StarTicketsWeb.TVLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Tickets
  alias StarTickets.Accounts

  # 10 seconds default
  @rotation_interval_ms 10_000

  @impl true
  def mount(_params, session, socket) do
    # Get current user from session for establishment filtering
    user = socket.assigns[:current_scope] && socket.assigns.current_scope.user
    establishment_id = user && user.establishment_id

    # Get TV configuration
    # For TV users: load their associated TV config
    # For admins: try to load first TV from their establishment (for testing purposes)
    tv_config =
      cond do
        user && user.role == "tv" ->
          get_tv_config(user.id)

        user && user.role in ["admin", "manager"] && establishment_id ->
          # For admins, get the first TV of the establishment to preview
          get_first_tv_config(establishment_id)

        true ->
          %{room_ids: [], all_rooms: true, news_enabled: false, news_url: nil}
      end

    socket =
      socket
      |> assign(:establishment_id, establishment_id)
      |> assign(:establishment_name, get_establishment_name(establishment_id))
      |> assign(:tv_config, tv_config)
      |> assign(:incoming_queue, [])
      |> assign(:rotation_queue, [])
      |> assign(:current_ticket, nil)
      |> assign(:history, [])
      |> assign(:rotation_timer, nil)
      |> assign(:rotation_index, 0)
      |> assign(:config, %{interval_ms: @rotation_interval_ms, tts_enabled: true})

    if connected?(socket) do
      # Subscribe to ticket events
      Tickets.subscribe()

      # Load initial called tickets
      socket = load_called_tickets(socket)

      # Start rotation if we have tickets
      {:ok, maybe_start_rotation(socket)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info({:ticket_called, ticket}, socket) do
    # Filter by establishment
    if ticket.establishment_id == socket.assigns.establishment_id do
      # Filter by configured rooms (if TV has room filter)
      if should_show_ticket?(ticket, socket.assigns.tv_config) do
        socket = add_incoming_call(socket, ticket)
        {:noreply, socket}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:ticket_updated, _ticket}, socket) do
    # Reload rotation queue when any ticket is updated
    socket = load_called_tickets(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    # Timer expired, process next ticket
    socket = process_next(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # ============================================
  # Core Logic
  # ============================================

  defp add_incoming_call(socket, ticket) do
    # Normalize ticket data
    ticket_data = normalize_ticket(ticket)

    # 1. Add to incoming queue (priority)
    incoming_queue = socket.assigns.incoming_queue ++ [ticket_data]

    # 2. Also add to rotation queue if not already there
    rotation_queue = socket.assigns.rotation_queue

    rotation_queue =
      if Enum.any?(rotation_queue, &(&1.id == ticket_data.id)) do
        rotation_queue
      else
        rotation_queue ++ [ticket_data]
      end

    socket = assign(socket, incoming_queue: incoming_queue, rotation_queue: rotation_queue)

    # 3. If TV is idle (no timer), start immediately
    if socket.assigns.rotation_timer == nil do
      process_next(socket)
    else
      # Wait for current slot to finish
      socket
    end
  end

  defp process_next(socket) do
    # Cancel existing timer
    socket = cancel_timer(socket)

    cond do
      # PRIORITY 1: Incoming queue (new calls with TTS)
      length(socket.assigns.incoming_queue) > 0 ->
        [ticket | rest] = socket.assigns.incoming_queue

        socket
        |> assign(:incoming_queue, rest)
        |> assign(:current_ticket, ticket)
        |> add_to_history(ticket)
        |> push_event("play_alert", %{})
        |> push_event("speak", %{text: build_speech_text(ticket)})
        |> start_timer()

      # PRIORITY 2: Rotation queue (passive rotation)
      length(socket.assigns.rotation_queue) > 0 ->
        rotation_queue = socket.assigns.rotation_queue
        index = rem(socket.assigns.rotation_index, length(rotation_queue))
        ticket = Enum.at(rotation_queue, index)

        socket
        |> assign(:current_ticket, ticket)
        |> assign(:rotation_index, index + 1)
        |> push_event("play_alert", %{})
        |> start_timer()

      # IDLE: No tickets
      true ->
        assign(socket, :current_ticket, nil)
    end
  end

  defp add_to_history(socket, ticket) do
    history = [ticket | socket.assigns.history] |> Enum.take(5)
    assign(socket, :history, history)
  end

  defp start_timer(socket) do
    timer = Process.send_after(self(), :tick, socket.assigns.config.interval_ms)
    assign(socket, :rotation_timer, timer)
  end

  defp cancel_timer(socket) do
    if socket.assigns.rotation_timer do
      Process.cancel_timer(socket.assigns.rotation_timer)
    end

    assign(socket, :rotation_timer, nil)
  end

  defp maybe_start_rotation(socket) do
    if socket.assigns.current_ticket == nil && length(socket.assigns.rotation_queue) > 0 do
      process_next(socket)
    else
      socket
    end
  end

  # ============================================
  # Data Loading
  # ============================================

  defp load_called_tickets(socket) do
    establishment_id = socket.assigns.establishment_id

    if establishment_id do
      # Get tickets with status CALLED or CALLED_RECEPTION
      tickets = Tickets.list_called_tickets(establishment_id)

      # Filter by TV's configured rooms
      tickets = Enum.filter(tickets, &should_show_ticket?(&1, socket.assigns.tv_config))

      # Normalize
      rotation_queue = Enum.map(tickets, &normalize_ticket/1)

      assign(socket, :rotation_queue, rotation_queue)
    else
      socket
    end
  end

  defp normalize_ticket(ticket) do
    %{
      id: ticket.id,
      display_code: ticket.display_code,
      customer_name: ticket.customer_name || "Cliente",
      room_name: get_room_name(ticket),
      called_at: ticket.updated_at
    }
  end

  defp get_room_name(ticket) do
    cond do
      ticket.room && ticket.room.name -> ticket.room.name
      Map.has_key?(ticket, :room_name) -> ticket.room_name
      true -> "---"
    end
  end

  defp should_show_ticket?(ticket, tv_config) do
    # If all_rooms is true, show all tickets
    if tv_config[:all_rooms] do
      true
    else
      # Otherwise, check if ticket's room is in the configured list
      room_id = ticket.room_id || (ticket.room && ticket.room.id)
      room_id in (tv_config[:room_ids] || [])
    end
  end

  defp get_tv_config(user_id) do
    # Get TV associated with this user
    case Accounts.get_tv_by_user(user_id) do
      nil ->
        %{room_ids: [], all_rooms: true, news_enabled: false, news_url: nil}

      tv ->
        tv = StarTickets.Repo.preload(tv, :rooms)

        %{
          room_ids: Enum.map(tv.rooms, & &1.id),
          all_rooms: tv.all_rooms,
          news_enabled: tv.news_enabled || false,
          news_url: tv.news_url
        }
    end
  end

  defp get_first_tv_config(establishment_id) do
    # Get the first TV from the establishment for admin preview
    case Accounts.list_tvs(establishment_id) |> List.first() do
      nil ->
        %{room_ids: [], all_rooms: true, news_enabled: false, news_url: nil}

      tv ->
        %{
          room_ids: Enum.map(tv.rooms, & &1.id),
          all_rooms: tv.all_rooms,
          news_enabled: tv.news_enabled || false,
          news_url: tv.news_url
        }
    end
  end

  defp get_establishment_name(nil), do: "Star Tickets"

  defp get_establishment_name(establishment_id) do
    case Accounts.get_establishment(establishment_id) do
      nil -> "Star Tickets"
      est -> est.name
    end
  end

  defp build_speech_text(ticket) do
    if ticket.customer_name && ticket.customer_name != "Cliente" do
      "#{ticket.customer_name}, compareça à #{ticket.room_name}"
    else
      "Senha #{ticket.display_code}, compareça à #{ticket.room_name}"
    end
  end

  defp convert_to_embed_url(url) when is_binary(url) do
    cond do
      # YouTube watch URL: https://www.youtube.com/watch?v=VIDEO_ID
      String.contains?(url, "youtube.com/watch") ->
        case Regex.run(~r/[?&]v=([^&]+)/, url) do
          [_, video_id] -> "https://www.youtube.com/embed/#{video_id}?autoplay=1&mute=1"
          _ -> url
        end

      # YouTube short URL: https://youtu.be/VIDEO_ID
      String.contains?(url, "youtu.be/") ->
        case Regex.run(~r/youtu\.be\/([^?&]+)/, url) do
          [_, video_id] -> "https://www.youtube.com/embed/#{video_id}?autoplay=1&mute=1"
          _ -> url
        end

      # YouTube live URL: https://www.youtube.com/live/VIDEO_ID
      String.contains?(url, "youtube.com/live/") ->
        case Regex.run(~r/youtube\.com\/live\/([^?&]+)/, url) do
          [_, video_id] -> "https://www.youtube.com/embed/#{video_id}?autoplay=1&mute=1"
          _ -> url
        end

      # Already an embed URL or other URL
      true ->
        url
    end
  end

  defp convert_to_embed_url(_), do: nil

  # ============================================
  # Render
  # ============================================

  @impl true
  def render(assigns) do
    ~H"""
    <div id="tv-container" class={["st-app has-background tv-page", @tv_config[:news_enabled] && "tv-with-video"]} phx-hook="TVSound">
      <%= if @tv_config[:news_enabled] && @tv_config[:news_url] do %>
        <%!-- Split Layout: Video + Tickets --%>
        <div class="tv-video-split-container">
          <%!-- Left Side: Video/YouTube --%>
          <div class="tv-video-side">
            <iframe
              src={convert_to_embed_url(@tv_config[:news_url])}
              class="tv-video-iframe"
              frameborder="0"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowfullscreen
            ></iframe>
          </div>

          <%!-- Right Side: Tickets --%>
          <div class="tv-tickets-side">
            <div class="tv-main-card-compact">
              <div class="tv-establishment-name-small"><%= @establishment_name %></div>

              <%= if @current_ticket do %>
                <div class="tv-ticket-display-compact animate-pulse-once">
                  <div class="tv-customer-name-small"><%= @current_ticket.customer_name %></div>
                  <div class="tv-ticket-code-small"><%= @current_ticket.display_code %></div>
                  <div class="tv-room-name-small">
                    <span class="tv-room-label-small">Compareça à:</span>
                    <span class="tv-room-value-small"><%= @current_ticket.room_name %></span>
                  </div>
                </div>
              <% else %>
                <div class="tv-ticket-display-compact tv-idle">
                  <div class="tv-customer-name-small">Aguardando...</div>
                  <div class="tv-ticket-code-small">---</div>
                </div>
              <% end %>

              <%!-- Last calls mini list --%>
              <div class="tv-mini-history">
                <%= for ticket <- Enum.take(@history, 3) do %>
                  <div class="tv-mini-history-item">
                    <span class="code"><%= ticket.display_code %></span>
                    <span class="room"><%= ticket.room_name %></span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <%!-- Normal Layout: Full Tickets --%>
        <div class="tv-split-container">
          <!-- Left Side: Main Ticket Display -->
          <div class="tv-split-left">
            <div class="tv-main-card">
              <div class="tv-establishment-name"><%= @establishment_name %></div>

              <%= if @current_ticket do %>
                <div class="tv-ticket-display animate-pulse-once">
                  <div class="tv-customer-name"><%= @current_ticket.customer_name %></div>
                  <div class="tv-ticket-code"><%= @current_ticket.display_code %></div>
                  <div class="tv-room-name">
                    <span class="tv-room-label">Compareça à:</span>
                    <span class="tv-room-value"><%= @current_ticket.room_name %></span>
                  </div>
                </div>
              <% else %>
                <div class="tv-ticket-display tv-idle">
                  <div class="tv-customer-name">Aguardando chamada...</div>
                  <div class="tv-ticket-code">---</div>
                  <div class="tv-room-name">---</div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Right Side: History -->
          <div class="tv-split-right">
            <div class="tv-history-section">
              <div class="tv-history-title">Últimas Chamadas</div>
              <div class="tv-history-list">
                <%= for ticket <- @history do %>
                  <div class="tv-history-item">
                    <span class="ticket-code"><%= ticket.display_code %></span>
                    <span class="customer-name"><%= ticket.customer_name %></span>
                    <span class="room-name"><%= ticket.room_name %></span>
                  </div>
                <% end %>
                <%= if Enum.empty?(@history) do %>
                  <div class="tv-history-empty">Nenhuma chamada recente</div>
                <% end %>
              </div>
            </div>

            <!-- Queue Status (Debug/Info) -->
            <div class="tv-queue-status">
              <span class="queue-badge">
                Fila: <%= length(@rotation_queue) %> senha(s)
              </span>
            </div>
          </div>
        </div>
      <% end %>
    </div>

    <style>
      .tv-page {
        width: 100vw;
        height: 100vh;
        overflow: hidden;
        font-family: 'Inter', 'Segoe UI', sans-serif;
      }

      .tv-split-container {
        display: flex;
        width: 100%;
        height: 100%;
      }

      .tv-split-left {
        flex: 2;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        position: relative;
        padding: 40px;
      }

      .tv-main-card {
        width: 100%;
        background: rgba(0, 0, 0, 0.3);
        backdrop-filter: blur(20px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 32px;
        padding: 60px 80px;
        text-align: center;
        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
      }

      .tv-split-right {
        flex: 1;
        display: flex;
        flex-direction: column;
        background: rgba(0, 0, 0, 0.3);
        backdrop-filter: blur(20px);
        border-left: 1px solid rgba(255, 255, 255, 0.1);
      }

      .tv-establishment-name {
        font-size: 1.8rem;
        color: rgba(255, 255, 255, 0.6);
        font-weight: 300;
        text-transform: uppercase;
        letter-spacing: 6px;
        margin-bottom: 30px;
        padding-bottom: 20px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.1);
      }

      .tv-ticket-display {
        text-align: center;
      }

      .tv-customer-name {
        font-size: 4rem;
        font-weight: 600;
        color: #fff;
        margin-bottom: 20px;
        text-shadow: 0 4px 20px rgba(0,0,0,0.3);
      }

      .tv-ticket-code {
        font-size: 12rem;
        font-weight: 800;
        color: #10b981;
        text-shadow: 0 0 60px rgba(16, 185, 129, 0.5);
        line-height: 1;
        margin-bottom: 40px;
      }

      .tv-room-name {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 10px;
      }

      .tv-room-label {
        font-size: 1.5rem;
        color: rgba(255, 255, 255, 0.5);
        text-transform: uppercase;
        letter-spacing: 4px;
      }

      .tv-room-value {
        font-size: 3.5rem;
        font-weight: 700;
        color: #f59e0b;
        text-shadow: 0 0 40px rgba(245, 158, 11, 0.4);
      }

      .tv-idle .tv-customer-name {
        color: rgba(255, 255, 255, 0.4);
        font-size: 2.5rem;
      }

      .tv-idle .tv-ticket-code {
        color: rgba(255, 255, 255, 0.2);
        font-size: 8rem;
      }

      /* History Section */
      .tv-history-section {
        flex: 1;
        padding: 30px;
        overflow: hidden;
      }

      .tv-history-title {
        font-size: 1.2rem;
        color: rgba(255, 255, 255, 0.6);
        text-transform: uppercase;
        letter-spacing: 3px;
        margin-bottom: 20px;
        padding-bottom: 10px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.1);
      }

      .tv-history-list {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }

      .tv-history-item {
        display: flex;
        align-items: center;
        gap: 15px;
        padding: 15px 20px;
        background: rgba(255, 255, 255, 0.05);
        border-radius: 12px;
        border-left: 4px solid #10b981;
      }

      .tv-history-item .ticket-code {
        font-size: 1.4rem;
        font-weight: 700;
        color: #10b981;
        min-width: 80px;
      }

      .tv-history-item .customer-name {
        flex: 1;
        font-size: 1.1rem;
        color: rgba(255, 255, 255, 0.9);
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .tv-history-item .room-name {
        font-size: 1rem;
        color: rgba(255, 255, 255, 0.5);
      }

      .tv-history-empty {
        color: rgba(255, 255, 255, 0.3);
        font-style: italic;
        text-align: center;
        padding: 40px;
      }

      .tv-queue-status {
        padding: 20px 30px;
        border-top: 1px solid rgba(255, 255, 255, 0.1);
      }

      .queue-badge {
        display: inline-block;
        padding: 8px 16px;
        background: rgba(16, 185, 129, 0.2);
        border: 1px solid rgba(16, 185, 129, 0.3);
        border-radius: 20px;
        color: #10b981;
        font-size: 0.9rem;
      }

      /* Animation */
      @keyframes pulse-once {
        0% { transform: scale(1); }
        50% { transform: scale(1.02); }
        100% { transform: scale(1); }
      }

      .animate-pulse-once {
        animation: pulse-once 0.5s ease-out;
      }

      /* ============================================ */
      /* Video Split Layout Styles                    */
      /* ============================================ */

      .tv-video-split-container {
        display: flex;
        width: 100%;
        height: 100%;
      }

      .tv-video-side {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 20px;
      }

      .tv-video-iframe {
        width: 100%;
        height: 100%;
        border-radius: 16px;
        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
      }

      .tv-tickets-side {
        flex: 1;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 20px;
      }

      .tv-main-card-compact {
        width: 100%;
        background: rgba(0, 0, 0, 0.3);
        backdrop-filter: blur(20px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 24px;
        padding: 30px 40px;
        text-align: center;
        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
      }

      .tv-establishment-name-small {
        font-size: 1.2rem;
        color: rgba(255, 255, 255, 0.6);
        font-weight: 300;
        text-transform: uppercase;
        letter-spacing: 4px;
        margin-bottom: 20px;
        padding-bottom: 15px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.1);
      }

      .tv-ticket-display-compact {
        text-align: center;
      }

      .tv-customer-name-small {
        font-size: 2rem;
        font-weight: 600;
        color: #fff;
        margin-bottom: 10px;
        text-shadow: 0 4px 20px rgba(0,0,0,0.3);
      }

      .tv-ticket-code-small {
        font-size: 6rem;
        font-weight: 800;
        color: #10b981;
        text-shadow: 0 0 40px rgba(16, 185, 129, 0.5);
        line-height: 1;
        margin-bottom: 15px;
      }

      .tv-room-name-small {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 5px;
      }

      .tv-room-label-small {
        font-size: 1rem;
        color: rgba(255, 255, 255, 0.5);
        text-transform: uppercase;
        letter-spacing: 2px;
      }

      .tv-room-value-small {
        font-size: 2rem;
        font-weight: 700;
        color: #f59e0b;
        text-shadow: 0 0 30px rgba(245, 158, 11, 0.4);
      }

      .tv-mini-history {
        margin-top: 20px;
        padding-top: 20px;
        border-top: 1px solid rgba(255, 255, 255, 0.1);
        display: flex;
        flex-direction: column;
        gap: 8px;
      }

      .tv-mini-history-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 10px 15px;
        background: rgba(255, 255, 255, 0.05);
        border-radius: 10px;
        border-left: 3px solid #10b981;
      }

      .tv-mini-history-item .code {
        font-size: 1.2rem;
        font-weight: 700;
        color: #10b981;
      }

      .tv-mini-history-item .room {
        font-size: 0.9rem;
        color: rgba(255, 255, 255, 0.6);
      }

      .tv-ticket-display-compact.tv-idle .tv-customer-name-small {
        color: rgba(255, 255, 255, 0.4);
        font-size: 1.5rem;
      }

      .tv-ticket-display-compact.tv-idle .tv-ticket-code-small {
        color: rgba(255, 255, 255, 0.2);
        font-size: 4rem;
      }
    </style>
    """
  end
end
