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
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: "Too many requests. Please wait."}))
        |> halt()
    end
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
