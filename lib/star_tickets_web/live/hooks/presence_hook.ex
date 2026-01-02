defmodule StarTicketsWeb.PresenceHook do
  @moduledoc """
  Automatically tracks user presence for any LiveView that mounts this hook.
  """
  import Phoenix.LiveView

  alias StarTicketsWeb.Presence

  @topic "system:presence"

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) && socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      user = socket.assigns.current_scope.user

      # Track the user
      # We use the user ID as the key so we can count unique users
      {:ok, _} =
        Presence.track(self(), @topic, user.id, %{
          name: user.name,
          role: user.role,
          online_at: System.system_time(:second)
          # You can add more metadata here like device payload if available
        })
    end

    {:cont, socket}
  end
end
