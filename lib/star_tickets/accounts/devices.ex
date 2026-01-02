defmodule StarTickets.Accounts.Devices do
  @moduledoc """
  Functions for managing user devices and sessions.
  """

  import Ecto.Query
  alias StarTickets.Repo
  alias StarTickets.Accounts.UserToken

  @doc """
  Lists all active session devices for a user.
  Only returns tokens with context "session" that haven't expired.
  """
  def list_user_devices(user_id) do
    session_validity_days = 14

    UserToken
    |> where([t], t.user_id == ^user_id)
    |> where([t], t.context == "session")
    |> where([t], t.inserted_at > ago(^session_validity_days, "day"))
    |> order_by([t], desc: t.last_used_at, desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a specific device token by ID for a user.
  """
  def get_device(token_id, user_id) do
    UserToken
    |> where([t], t.id == ^token_id and t.user_id == ^user_id)
    |> where([t], t.context == "session")
    |> Repo.one()
  end

  @doc """
  Revokes a specific device session.
  """
  def revoke_device(token_id, user_id) do
    case get_device(token_id, user_id) do
      nil ->
        {:error, :not_found}

      token ->
        Repo.delete(token)
        {:ok, :revoked}
    end
  end

  @doc """
  Revokes all device sessions for a user except the current one.
  """
  def revoke_all_devices(user_id, except_token) do
    {count, _} =
      UserToken
      |> where([t], t.user_id == ^user_id)
      |> where([t], t.context == "session")
      |> where([t], t.token != ^except_token)
      |> Repo.delete_all()

    {:ok, count}
  end

  @doc """
  Updates the last_used_at timestamp for a session token.
  """
  def update_last_used(token) when is_binary(token) do
    now = DateTime.utc_now(:second)

    UserToken
    |> where([t], t.token == ^token and t.context == "session")
    |> Repo.update_all(set: [last_used_at: now])
  end

  @doc """
  Parses User-Agent string to extract device information.
  Returns a map with :device_name, :device_type, :browser, :os
  """
  def parse_user_agent(nil), do: default_device_info()
  def parse_user_agent(""), do: default_device_info()

  def parse_user_agent(user_agent) do
    browser = detect_browser(user_agent)
    os = detect_os(user_agent)
    device_type = detect_device_type(user_agent)
    device_name = "#{browser} on #{os}"

    %{
      device_name: device_name,
      device_type: device_type,
      browser: browser,
      os: os
    }
  end

  defp default_device_info do
    %{
      device_name: "Unknown Device",
      device_type: "unknown",
      browser: "Unknown",
      os: "Unknown"
    }
  end

  defp detect_browser(ua) do
    cond do
      String.contains?(ua, "Edg/") ->
        extract_version(ua, ~r/Edg\/([\d.]+)/, "Edge")

      String.contains?(ua, "OPR/") or String.contains?(ua, "Opera") ->
        extract_version(ua, ~r/(?:OPR|Opera)\/([\d.]+)/, "Opera")

      String.contains?(ua, "Chrome/") and not String.contains?(ua, "Edg/") ->
        extract_version(ua, ~r/Chrome\/([\d.]+)/, "Chrome")

      String.contains?(ua, "Safari/") and not String.contains?(ua, "Chrome") ->
        extract_version(ua, ~r/Version\/([\d.]+)/, "Safari")

      String.contains?(ua, "Firefox/") ->
        extract_version(ua, ~r/Firefox\/([\d.]+)/, "Firefox")

      true ->
        "Unknown Browser"
    end
  end

  defp detect_os(ua) do
    cond do
      String.contains?(ua, "Windows NT 10") ->
        "Windows 10/11"

      String.contains?(ua, "Windows NT 6.3") ->
        "Windows 8.1"

      String.contains?(ua, "Windows NT 6.2") ->
        "Windows 8"

      String.contains?(ua, "Windows NT 6.1") ->
        "Windows 7"

      String.contains?(ua, "Windows") ->
        "Windows"

      String.contains?(ua, "Mac OS X") ->
        extract_version(ua, ~r/Mac OS X ([\d_]+)/, "macOS") |> String.replace("_", ".")

      String.contains?(ua, "Android") ->
        extract_version(ua, ~r/Android ([\d.]+)/, "Android")

      String.contains?(ua, "iPhone") or String.contains?(ua, "iPad") ->
        extract_version(ua, ~r/OS ([\d_]+)/, "iOS") |> String.replace("_", ".")

      String.contains?(ua, "Linux") ->
        "Linux"

      true ->
        "Unknown OS"
    end
  end

  defp detect_device_type(ua) do
    cond do
      String.contains?(ua, "Mobile") or
          (String.contains?(ua, "Android") and not String.contains?(ua, "Tablet")) ->
        "mobile"

      String.contains?(ua, "Tablet") or String.contains?(ua, "iPad") ->
        "tablet"

      true ->
        "desktop"
    end
  end

  defp extract_version(ua, regex, name) do
    case Regex.run(regex, ua) do
      [_, version] -> "#{name} #{version |> String.split(".") |> Enum.take(2) |> Enum.join(".")}"
      _ -> name
    end
  end

  @doc """
  Returns an icon class based on device type.
  """
  def device_icon(device_type) do
    case device_type do
      "mobile" -> "fa-mobile-screen"
      "tablet" -> "fa-tablet-screen-button"
      "desktop" -> "fa-desktop"
      _ -> "fa-laptop"
    end
  end
end
