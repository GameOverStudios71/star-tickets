defmodule StarTickets.Notifications.WhatsApp do
  @moduledoc """
  Handles sending WhatsApp messages to users.
  Currently a mock integration that logs messages.
  """
  require Logger

  @doc """
  Sends a WhatsApp message to a specific number.
  """
  def send_message(to_number, message) do
    if is_binary(to_number) and to_number != "" do
      # In production, this would call an API like WppConnect, Twilio, Gupshup, etc.
      Logger.info("""
      📱 [WhatsApp Mock] Sending to #{to_number}:
      --------------------------------------------------
      #{message}
      --------------------------------------------------
      """)

      {:ok, :sent}
    else
      {:error, :no_number}
    end
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
