defmodule StarTicketsWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using Hammer.
  Protects endpoints from excessive requests per IP.

  Usage in router:
    plug StarTicketsWeb.Plugs.RateLimiter, limit: 60, period: 60_000
  """
  import Plug.Conn

  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, 100),
      # 1 minute default
      period: Keyword.get(opts, :period, 60_000)
    }
  end

  def call(conn, %{limit: limit, period: period}) do
    key = rate_limit_key(conn)

    case Hammer.check_rate(key, period, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        # Log the rate limit violation as a critical event
        log_rate_limit_violation(conn, limit, period)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: "Too many requests. Please wait."}))
        |> halt()
    end
  end

  defp log_rate_limit_violation(conn, limit, period) do
    ip = get_client_ip(conn)
    path = conn.request_path

    # Log as audit event - this will trigger notification dispatcher
    StarTickets.Audit.log_action(
      "SYSTEM_ALERT_RATE_LIMIT_EXCEEDED",
      %{
        resource_type: "Security",
        resource_id: ip,
        details: %{
          message: "Rate limit exceeded: #{limit} requests in #{div(period, 1000)}s",
          ip: ip,
          path: path,
          method: conn.method
        },
        metadata: %{severity: "warning"},
        # System user
        user_id: 1
      }
    )
  end

  defp rate_limit_key(conn) do
    ip = get_client_ip(conn)
    "rate_limit:#{ip}"
  end

  defp get_client_ip(conn) do
    # Try X-Forwarded-For first
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded |> String.split(",") |> List.first() |> String.trim()

      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
