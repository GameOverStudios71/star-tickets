defmodule StarTicketsWeb.UserLive.Devices do
  use StarTicketsWeb, :live_view

  alias StarTickets.Accounts.Devices

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_scope.user
    current_token = session["user_token"]

    devices = Devices.list_user_devices(user.id)

    {:ok,
     socket
     |> assign(:devices, devices)
     |> assign(:current_token, current_token)
     |> assign(:page_title, "Dispositivos Conectados")}
  end

  @impl true
  def handle_event("revoke_device", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    token_id = String.to_integer(id)

    case Devices.revoke_device(token_id, user.id) do
      {:ok, :revoked} ->
        devices = Devices.list_user_devices(user.id)

        {:noreply,
         socket
         |> assign(:devices, devices)
         |> put_flash(:info, "Dispositivo desconectado com sucesso.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Dispositivo não encontrado.")}
    end
  end

  @impl true
  def handle_event("revoke_all", _params, socket) do
    user = socket.assigns.current_scope.user
    current_token = socket.assigns.current_token

    case Devices.revoke_all_devices(user.id, current_token) do
      {:ok, count} ->
        devices = Devices.list_user_devices(user.id)

        {:noreply,
         socket
         |> assign(:devices, devices)
         |> put_flash(:info, "#{count} dispositivo(s) desconectado(s).")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col">
      <.app_header
        title="Dispositivos Conectados"
        show_home={true}
        current_scope={@current_scope}
        {assigns}
      />

      <div class="st-container flex-1 p-6">
        <%!-- Breadcrumb --%>
        <div class="mb-6 max-w-4xl mx-auto">
          <div class="st-card st-acrylic px-4 py-2 inline-block rounded-full">
            <.breadcrumb items={[
              %{label: "Meus Dados", href: ~p"/users/settings"},
              %{label: "Dispositivos Conectados"}
            ]} />
          </div>
        </div>

        <div class="max-w-4xl mx-auto">
          <%!-- Header Section --%>
          <div class="bg-white/5 backdrop-blur-md rounded-2xl p-6 border border-white/10 mb-6">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-2xl font-bold text-white flex items-center gap-3">
                  <i class="fa-solid fa-shield-halved text-emerald-400"></i> Seus Dispositivos
                </h2>
                <p class="text-white/60 mt-1">
                  Gerencie os dispositivos conectados à sua conta
                </p>
              </div>
              <%= if length(@devices) > 1 do %>
                <button
                  phx-click="revoke_all"
                  data-confirm="Deseja desconectar todos os outros dispositivos?"
                  class="px-4 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-400 rounded-lg border border-red-500/30 transition-all"
                >
                  <i class="fa-solid fa-right-from-bracket mr-2"></i> Desconectar Outros
                </button>
              <% end %>
            </div>
          </div>

          <%!-- Devices List --%>
          <div class="space-y-4">
            <%= for device <- @devices do %>
              <% is_current = device.token == @current_token %>
              <div class={"bg-white/5 backdrop-blur-md rounded-xl p-5 border transition-all " <>
                if(is_current, do: "border-emerald-500/40 bg-emerald-500/10", else: "border-white/10 hover:border-white/20")}>
                <div class="flex items-start justify-between">
                  <div class="flex items-start gap-4">
                    <%!-- Device Icon --%>
                    <div class={"w-12 h-12 rounded-full flex items-center justify-center " <>
                      if(is_current, do: "bg-emerald-500/20 text-emerald-400", else: "bg-white/10 text-white/60")}>
                      <i class={"fa-solid #{Devices.device_icon(device.device_type)} text-xl"}></i>
                    </div>

                    <%!-- Device Info --%>
                    <div>
                      <div class="flex items-center gap-2">
                        <span class="font-semibold text-white text-lg">
                          {device.device_name || "Dispositivo Desconhecido"}
                        </span>
                        <%= if is_current do %>
                          <span class="px-2 py-0.5 bg-emerald-500 text-white text-xs rounded-full font-medium">
                            Este dispositivo
                          </span>
                        <% end %>
                      </div>

                      <div class="text-white/60 text-sm mt-1 space-y-1">
                        <div class="flex flex-wrap items-center gap-x-4 gap-y-1">
                          <%= if device.browser do %>
                            <span><i class="fa-solid fa-globe mr-1"></i>{device.browser}</span>
                          <% end %>
                          <%= if device.os do %>
                            <span><i class="fa-solid fa-desktop mr-1"></i>{device.os}</span>
                          <% end %>
                          <%= if device.screen_resolution do %>
                            <span>
                              <i class="fa-solid fa-display mr-1"></i>{device.screen_resolution}
                            </span>
                          <% end %>
                        </div>

                        <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-white/50">
                          <%= if device.cpu_cores do %>
                            <span>
                              <i class="fa-solid fa-microchip mr-1"></i>{device.cpu_cores} cores
                            </span>
                          <% end %>
                          <%= if device.memory_gb do %>
                            <span><i class="fa-solid fa-memory mr-1"></i>{device.memory_gb} GB</span>
                          <% end %>
                          <%= if device.timezone do %>
                            <span>
                              <i class="fa-solid fa-earth-americas mr-1"></i>{device.timezone}
                            </span>
                          <% end %>
                        </div>

                        <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-white/40">
                          <%= if device.ip_address do %>
                            <span>
                              <i class="fa-solid fa-network-wired mr-1"></i>{device.ip_address}
                            </span>
                          <% end %>
                          <span>
                            <i class="fa-solid fa-clock mr-1"></i>
                            <%= if device.last_used_at do %>
                              Último acesso: {format_datetime(device.last_used_at)}
                            <% else %>
                              Conectado em: {format_datetime(device.inserted_at)}
                            <% end %>
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>

                  <%!-- Actions --%>
                  <%= unless is_current do %>
                    <button
                      phx-click="revoke_device"
                      phx-value-id={device.id}
                      data-confirm="Deseja desconectar este dispositivo?"
                      class="px-3 py-1.5 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/20 transition-all text-sm"
                    >
                      <i class="fa-solid fa-xmark mr-1"></i> Desconectar
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if Enum.empty?(@devices) do %>
              <div class="text-center py-12 text-white/40">
                <i class="fa-solid fa-laptop text-4xl mb-4"></i>
                <p>Nenhum dispositivo encontrado</p>
              </div>
            <% end %>
          </div>

          <%!-- Info Card --%>
          <div class="mt-6 p-4 bg-blue-500/10 backdrop-blur-md border border-blue-500/30 rounded-xl shadow-lg">
            <div class="flex gap-3">
              <i class="fa-solid fa-circle-info text-blue-400 mt-0.5"></i>
              <div class="text-sm text-white/80">
                <p class="font-medium text-blue-300 mb-1">Dica de segurança</p>
                <p>
                  Se você não reconhece algum dispositivo, desconecte-o imediatamente e considere alterar sua senha.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_datetime(nil), do: "Desconhecido"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%d/%m/%Y às %H:%M")
  end
end
