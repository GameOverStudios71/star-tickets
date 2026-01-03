defmodule StarTickets.Notifications.WhatsApp do
  @moduledoc """
  Handles sending WhatsApp messages to users using Evolution API.
  Falls back to Mock log if not configured.
  """
  require Logger

  @doc """
  Sends a WhatsApp message to a specific number.
  """
  def send_message(to_number, message) do
    if is_binary(to_number) and to_number != "" do
      config = Application.get_env(:star_tickets, :evolution_api, [])
      url = config[:url]
      api_key = config[:api_key]
      instance = config[:instance_name]

      if url && api_key do
        send_via_evolution(url, api_key, instance, to_number, message)
      else
        log_mock_message(to_number, message)
      end
    else
      {:error, :no_number}
    end
  end

  defp send_via_evolution(url, api_key, instance, number, message) do
    endpoint = "#{url}/message/sendText/#{instance}"

    # Format number: remove non-digits
    clean_number = String.replace(number, ~r/\D/, "")

    # Evolution often expects country code. Assuming Brazil (55) if length is 10 or 11
    # But ideally number should be stored with DDI in user struct.
    # We'll assume the stored number is usable, just cleaning format.

    payload = %{
      number: clean_number,
      text: message,
      delay: 1200,
      linkPreview: true
    }

    headers = [
      {"apikey", api_key},
      {"Content-Type", "application/json"}
    ]

    case Req.post(endpoint, json: payload, headers: headers) do
      {:ok, %{status: 201}} ->
        Logger.info("✅ [WhatsApp] Message sent to #{clean_number} via Evolution API")
        {:ok, :sent}

      {:ok, %{status: 200}} ->
        Logger.info("✅ [WhatsApp] Message sent to #{clean_number} via Evolution API")
        {:ok, :sent}

      {:ok, %{status: status, body: body}} ->
        Logger.error(
          "❌ [WhatsApp] Failed to send to #{clean_number}. Status: #{status}. Body: #{inspect(body)}"
        )

        {:error, :api_error}

      {:error, reason} ->
        Logger.error("❌ [WhatsApp] Network error: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp log_mock_message(to_number, message) do
    Logger.info("""
    📱 [WhatsApp Mock] Sending to #{to_number}:
    --------------------------------------------------
    #{message}
    --------------------------------------------------
    """)

    {:ok, :sent}
  end

  @doc """
  Sends a critical alert to a user.
  """
  def send_alert(user, title, details) do
    if user && user.phone_number do
      message = """
      🚨 *Star Tickets Alert* 🚨

      *#{title}*

      #{details}
      """

      send_message(user.phone_number, message)
    else
      {:error, :no_phone_or_user}
    end
  end
end
