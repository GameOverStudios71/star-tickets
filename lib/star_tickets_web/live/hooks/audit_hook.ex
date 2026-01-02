defmodule StarTicketsWeb.AuditHook do
  import Phoenix.LiveView
  import Phoenix.Component
  alias StarTickets.Audit
  alias StarTickets.Accounts.Devices

  def on_mount(:default, _params, session, socket) do
    # Fetch device info from session token
    audit_metadata = fetch_audit_metadata(session)

    socket = assign(socket, :audit_metadata, audit_metadata)

    # Register Page Access
    log_page_view(socket)

    # Attach hooks for everything else
    {:cont,
     socket
     |> attach_hook(:audit_event, :handle_event, &audit_handle_event/3)
     |> attach_hook(:audit_info, :handle_info, &audit_handle_info/2)}
  end

  defp audit_handle_event(event, params, socket) do
    # Filter sensitive params like passwords if necessary
    safe_params = filter_params(params)

    metadata =
      Map.merge(
        %{uri: socket.assigns[:current_uri] || "unknown"},
        socket.assigns[:audit_metadata] || %{}
      )

    Audit.log_action(
      "UI_EVENT",
      %{
        resource_type: "LiveView",
        resource_id: to_string(socket.view),
        details: %{
          event: event,
          params: safe_params
        },
        metadata: metadata
      },
      get_user(socket)
    )

    {:cont, socket}
  end

  defp audit_handle_info({:audit_log_created, _}, socket), do: {:cont, socket}

  defp audit_handle_info(msg, socket) do
    # Log PubSub messages or internal infos
    # Be careful with huge payloads
    safe_msg = inspect(msg, limit: 100)

    Audit.log_action(
      "UI_INFO",
      %{
        resource_type: "LiveView",
        resource_id: to_string(socket.view),
        details: %{
          message_inspect: safe_msg
        },
        metadata: socket.assigns[:audit_metadata] || %{}
      },
      get_user(socket)
    )

    {:cont, socket}
  end

  defp log_page_view(socket) do
    metadata =
      Map.merge(
        %{uri: socket.assigns[:current_uri] || "unknown"},
        socket.assigns[:audit_metadata] || %{}
      )

    Audit.log_action(
      "PAGE_VIEW",
      %{
        resource_type: "LiveView",
        resource_id: to_string(socket.view),
        details: %{},
        metadata: metadata
      },
      get_user(socket)
    )
  end

  defp get_user(socket) do
    cond do
      socket.assigns[:current_user] -> socket.assigns.current_user
      socket.assigns[:current_scope] -> socket.assigns.current_scope.user
      true -> nil
    end
  end

  defp fetch_audit_metadata(session) do
    case session["user_token"] do
      token when is_binary(token) ->
        case Devices.get_device_by_token(token) do
          nil ->
            %{}

          device ->
            %{
              ip_address: device.ip_address,
              device_name: device.device_name,
              os: device.os,
              browser: device.browser,
              device_type: device.device_type,
              location: device.location
            }
        end

      _ ->
        %{}
    end
  end

  defp filter_params(params) do
    # Basic redaction
    params
    |> Map.drop(["password", "password_confirmation", "_csrf_token"])
  end
end
