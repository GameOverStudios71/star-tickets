defmodule StarTicketsWeb.Admin.NotificationSettingsLive do
  use StarTicketsWeb, :live_view
  alias StarTickets.Notifications.Setting

  def mount(_params, _session, socket) do
    # Ensure default settings exist for all types
    ensure_defaults()

    settings = Setting.list_settings()

    # Organize by type for easier display
    grouped_settings = Enum.group_by(settings, & &1.notification_type)

    notification_types = [
      "TOTEM_OFFLINE",
      "RECEPTION_OFFLINE",
      "TV_OFFLINE",
      "PROFESSIONAL_OFFLINE",
      "RATE_LIMIT",
      "SYSTEM_ERROR"
    ]

    {:ok,
     socket
     |> assign(:page_title, "Configuração de Notificações")
     |> assign(:grouped_settings, grouped_settings)
     |> assign(:notification_types, notification_types)}
  end

  def handle_event("toggle_whatsapp", %{"type" => type, "role" => role}, socket) do
    {:ok, setting} = Setting.get_or_create_setting(type, role)

    {:ok, _updated_setting} =
      Setting.update_setting(setting, %{whatsapp_enabled: !setting.whatsapp_enabled})

    # Refresh settings
    settings = Setting.list_settings()
    grouped_settings = Enum.group_by(settings, & &1.notification_type)

    {:noreply, assign(socket, :grouped_settings, grouped_settings)}
  end

  defp ensure_defaults do
    # Create defaults if they don't exist
    types = [
      "TOTEM_OFFLINE",
      "RECEPTION_OFFLINE",
      "TV_OFFLINE",
      "PROFESSIONAL_OFFLINE",
      "RATE_LIMIT",
      "SYSTEM_ERROR"
    ]

    roles = ["admin", "manager"]

    for type <- types, role <- roles do
      Setting.get_or_create_setting(type, role)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-20">
      <.app_header
        title="Configurações"
        show_home={true}
        current_scope={@current_scope}
        client_name={@client_name}
        establishments={@establishments}
        users={@users}
        impersonating={@impersonating}
      />

      <div class="st-container flex-1 m-4" style="margin-top: 0;">
        <.page_header
          title="🔔 Configuração de Notificações"
          description="Gerencie quais alertas são enviados via WhatsApp."
          breadcrumb_items={[
            %{label: "Gerente", path: ~p"/manager"},
            %{label: "Notificações"}
          ]}
        >
          <div class="mt-8 overflow-x-auto">
            <table class="w-full text-left border-collapse">
              <thead>
                <tr class="border-b border-white/10 text-white/50 text-sm uppercase tracking-wider">
                  <th class="p-4">Tipo de Alerta</th>
                  <th class="p-4 text-center">WhatsApp Admin</th>
                  <th class="p-4 text-center">WhatsApp Manager</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-white/5">
                <%= for type <- @notification_types do %>
                  <tr class="hover:bg-white/5 transition-colors">
                    <td class="p-4">
                      <div class="flex items-center gap-3">
                        <div class={"w-2 h-2 rounded-full " <> get_type_color(type)}></div>
                        <span class="font-bold text-white">{format_type(type)}</span>
                      </div>
                      <p class="text-xs text-white/50 mt-1 pl-5">{get_type_description(type)}</p>
                    </td>

                    <td class="p-4 text-center">
                      <.toggle_switch
                        enabled={get_setting(@grouped_settings, type, "admin")}
                        phx-click="toggle_whatsapp"
                        phx-value-type={type}
                        phx-value-role="admin"
                      />
                    </td>

                    <td class="p-4 text-center">
                      <.toggle_switch
                        enabled={get_setting(@grouped_settings, type, "manager")}
                        phx-click="toggle_whatsapp"
                        phx-value-type={type}
                        phx-value-role="manager"
                      />
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <div class="mt-8 p-4 bg-blue-500/10 border border-blue-500/20 rounded-xl flex items-start gap-4">
            <i class="fa-solid fa-circle-info text-blue-400 mt-1"></i>
            <div>
              <h3 class="text-blue-200 font-bold mb-1">Nota sobre Notificações</h3>
              <p class="text-blue-200/70 text-sm">
                As notificações via <strong>Caixa de Entrada</strong>
                (painel web) não podem ser desativadas e sempre registrarão todos os eventos para auditoria.
                Os controles acima afetam apenas o envio de mensagens via <strong>WhatsApp</strong>.
              </p>
            </div>
          </div>
        </.page_header>
      </div>
    </div>
    """
  end

  defp get_setting(grouped, type, role) do
    settings = Map.get(grouped, type, [])

    case Enum.find(settings, &(&1.role == role)) do
      # Default true
      nil -> true
      s -> s.whatsapp_enabled
    end
  end

  defp format_type("TOTEM_OFFLINE"), do: "Totem Offline"
  defp format_type("RECEPTION_OFFLINE"), do: "Recepção Offline"
  defp format_type("TV_OFFLINE"), do: "TV Offline"
  defp format_type("PROFESSIONAL_OFFLINE"), do: "Profissional Offline"
  defp format_type("RATE_LIMIT"), do: "Rate Limit Excedido"
  defp format_type("SYSTEM_ERROR"), do: "Erro de Sistema"
  defp format_type(other), do: other

  defp get_type_color("SYSTEM_ERROR"), do: "bg-red-500"
  defp get_type_color(_), do: "bg-yellow-500"

  defp get_type_description("TOTEM_OFFLINE"),
    do: "Quando todos os totems perdem conexão com o servidor."

  defp get_type_description("RECEPTION_OFFLINE"),
    do: "Quando nenhuma tela de recepção está ativa."

  defp get_type_description("TV_OFFLINE"), do: "Quando nenhuma TV de chamada está conectada."
  defp get_type_description("PROFESSIONAL_OFFLINE"), do: "Quando nenhum profissional está logado."

  defp get_type_description("RATE_LIMIT"),
    do: "Quando um IP excede o limite de requisições permitidas."

  defp get_type_description("SYSTEM_ERROR"), do: "Erros críticos de código (crashes, exceptions)."

  def toggle_switch(assigns) do
    ~H"""
    <button
      id={"toggle-#{String.downcase(@values[:type])}-#{@values[:role]}"}
      phx-click={@click}
      phx-value-type={@values[:type]}
      phx-value-role={@values[:role]}
      phx-hook="DebounceSubmit"
      class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:ring-offset-2 " <> if(@enabled, do: "bg-emerald-500", else: "bg-gray-700")}
      {@rest}
    >
      <span class={"inline-block h-4 w-4 transform rounded-full bg-white transition-transform " <> if(@enabled, do: "translate-x-6", else: "translate-x-1")} />
    </button>
    """
  end
end
