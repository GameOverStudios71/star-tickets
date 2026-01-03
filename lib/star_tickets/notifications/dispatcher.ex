defmodule StarTickets.Notifications.Dispatcher do
  @moduledoc """
  Listens for system events (Audit Logs) and dispatches external notifications (WhatsApp, Email)
  for critical issues.
  """
  use GenServer
  require Logger
  alias StarTickets.Accounts
  alias StarTickets.Notifications.WhatsApp
  import Ecto.Query

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Subscribe to audit logs to catch system errors
    Phoenix.PubSub.subscribe(StarTickets.PubSub, "audit_logs")
    {:ok, %{}}
  end

  @impl true
  def handle_info({:audit_log_created, log}, state) do
    if is_critical?(log) do
      send_critical_alert(log)
    end

    {:noreply, state}
  end

  defp is_critical?(log) do
    action = to_string(log.action)
    metadata = log.metadata || %{}
    severity = Map.get(metadata, "severity") || Map.get(metadata, :severity)

    cond do
      # explicit severity
      severity in ["error", "critical", "alert"] -> true
      # logic based on action name
      String.contains?(action, "ERROR") -> true
      String.contains?(action, "CRITICAL") -> true
      String.contains?(action, "ALERT") -> true
      true -> false
    end
  end

  defp send_critical_alert(log) do
    # Find admins to notify
    # For this system, we notify ALL admins, or maybe just the first one?
    # User said "first user... is admin... messages sent...".
    # We will notify all users with role 'admin' that have a phone number.

    admins = list_admins_with_phone()

    message = format_whatsapp_message(log)

    Enum.each(admins, fn admin ->
      WhatsApp.send_message(admin.phone_number, message)
    end)
  end

  defp list_admins_with_phone do
    # Notify ALL admins AND managers that have a phone number
    StarTickets.Repo.all(
      from u in Accounts.User,
        where: u.role in ["admin", "manager"] and not is_nil(u.phone_number),
        select: u
    )
  end

  defp format_whatsapp_message(log) do
    """
    🚨 *Star Tickets System Alert* 🚨

    *Action:* #{log.action}
    *Resource:* #{log.resource_type} ##{log.resource_id}

    *Details:*
    #{format_details(log.details)}

    _Time: #{Calendar.strftime(log.inserted_at, "%d/%m %H:%M:%S")}_
    """
  end

  defp format_details(details) when is_map(details) do
    # Try to extract a message or just dump JSON
    if Map.has_key?(details, "message") do
      details["message"]
    else
      inspect(details, pretty: true, limit: 200)
    end
  end

  defp format_details(details), do: inspect(details)
end
