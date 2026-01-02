defmodule StarTickets.Sentinel.LoggerHandler do
  @moduledoc """
  Custom Logger Handler that intercepts system errors and warnings
  and broadcasts them to Sentinel AI for monitoring.
  """
  require Logger
  alias Phoenix.PubSub

  @pubsub StarTickets.PubSub
  @audit_topic "audit_logs"

  @doc """
  Attaches this handler to Erlang's :logger.
  Call this from Application.start/2.
  """
  def attach do
    :logger.add_handler(:sentinel_handler, __MODULE__, %{
      level: :warning,
      config: %{}
    })
  end

  @doc """
  Called by :logger for each log event.
  We filter for :error and :warning levels and broadcast them.
  """
  def log(%{level: level, msg: msg, meta: meta}, _config) when level in [:error, :warning] do
    # Format the message
    message =
      case msg do
        {:string, str} -> to_string(str)
        {:report, report} -> inspect(report, limit: 200)
        {format, args} when is_list(args) -> :io_lib.format(format, args) |> to_string()
        other -> inspect(other, limit: 200)
      end

    # Filter out known Phoenix LiveView warnings that are expected behavior
    if should_ignore?(message) do
      :ok
    else
      # Extract useful metadata
      source = meta[:mfa] || meta[:module] || "System"
      file = meta[:file]
      line = meta[:line]

      # Create a pseudo-AuditLog struct for broadcasting
      # (We use a map that looks like an AuditLog for consistency)
      pseudo_log = %{
        id: System.unique_integer([:positive]),
        action: "SYSTEM_#{level |> to_string() |> String.upcase()}",
        resource_type: "ErlangLogger",
        resource_id: inspect(source),
        details: %{
          message: message,
          file: file,
          line: line,
          level: level
        },
        metadata: %{},
        user: nil,
        inserted_at: NaiveDateTime.utc_now()
      }

      # Broadcast to the audit_logs topic so Overseer picks it up
      PubSub.broadcast(@pubsub, @audit_topic, {:audit_log_created, pseudo_log})

      :ok
    end
  end

  # Patterns to ignore (expected Phoenix/LiveView behavior)
  defp should_ignore?(message) do
    ignored_patterns = [
      "redirecting across live_sessions",
      "A full page reload will be performed instead"
    ]

    Enum.any?(ignored_patterns, fn pattern ->
      String.contains?(message, pattern)
    end)
  end

  # Ignore other log levels
  def log(_event, _config), do: :ok
end
