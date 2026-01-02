defmodule StarTickets.Audit.Actions do
  @moduledoc """
  Centralized module for all audit action definitions.
  This ensures consistency across the application when filtering or displaying audit logs.
  """

  @doc """
  Returns all available audit actions grouped by category.
  """
  def all_grouped do
    %{
      "Autenticação" => [
        "USER_LOGIN",
        "USER_LOGIN_FAILED",
        "USER_LOGOUT"
      ],
      "Tickets" => [
        "TICKET_CREATED",
        "TICKET_UPDATED",
        "TICKET_CALLED",
        "TICKET_FINISHED",
        "TICKET_ASSIGNED",
        "TICKET_SERVICES_UPDATED"
      ],
      "WebCheckin" => [
        "WEBCHECKIN_STARTED",
        "WEBCHECKIN_COMPLETED"
      ],
      "Totem" => [
        "TOTEM_SESSION_START",
        "TOTEM_SERVICE_ADDED",
        "TOTEM_SERVICE_REMOVED",
        "TOTEM_TICKET_GENERATION_STARTED",
        "TOTEM_TICKET_PRINTED"
      ],
      "TV" => [
        "TV_SESSION_START",
        "TV_TICKET_RECEIVED",
        "TV_TICKET_DISPLAYED",
        "TV_TICKET_FILTERED"
      ],
      "Sistema" => [
        "PAGE_VIEW",
        "UI_EVENT",
        "SYSTEM_ERROR",
        "SYSTEM_WARNING"
      ]
    }
  end

  @doc """
  Returns all available audit actions as a flat sorted list.
  """
  def all do
    all_grouped()
    |> Map.values()
    |> List.flatten()
    |> Enum.sort()
  end

  @doc """
  Returns only high-priority actions for live monitoring.
  """
  def live_monitoring_defaults do
    [
      "TICKET_CREATED",
      "TICKET_CALLED",
      "TICKET_FINISHED",
      "WEBCHECKIN_STARTED",
      "WEBCHECKIN_COMPLETED",
      "TOTEM_TICKET_PRINTED",
      "SYSTEM_ERROR"
    ]
  end

  @doc """
  Returns action color for UI display.
  """
  def color_for(action) do
    cond do
      String.starts_with?(action, "USER_LOGIN_FAILED") -> "red"
      String.starts_with?(action, "USER_") -> "blue"
      String.starts_with?(action, "TICKET_") -> "green"
      String.starts_with?(action, "WEBCHECKIN_") -> "cyan"
      String.starts_with?(action, "TOTEM_") -> "amber"
      String.starts_with?(action, "TV_") -> "purple"
      String.starts_with?(action, "SYSTEM_ERROR") -> "red"
      String.starts_with?(action, "SYSTEM_WARNING") -> "yellow"
      action in ["PAGE_VIEW", "UI_EVENT"] -> "gray"
      true -> "slate"
    end
  end

  @doc """
  Returns icon class for action.
  """
  def icon_for(action) do
    cond do
      String.starts_with?(action, "USER_LOGIN") -> "fa-right-to-bracket"
      String.starts_with?(action, "USER_LOGOUT") -> "fa-right-from-bracket"
      String.starts_with?(action, "TICKET_CREATED") -> "fa-plus"
      String.starts_with?(action, "TICKET_CALLED") -> "fa-bullhorn"
      String.starts_with?(action, "TICKET_FINISHED") -> "fa-check"
      String.starts_with?(action, "TICKET_") -> "fa-ticket"
      String.starts_with?(action, "WEBCHECKIN_") -> "fa-mobile-screen"
      String.starts_with?(action, "TOTEM_") -> "fa-display"
      String.starts_with?(action, "TV_") -> "fa-tv"
      String.starts_with?(action, "SYSTEM_ERROR") -> "fa-circle-exclamation"
      String.starts_with?(action, "SYSTEM_WARNING") -> "fa-triangle-exclamation"
      action == "PAGE_VIEW" -> "fa-eye"
      action == "UI_EVENT" -> "fa-hand-pointer"
      true -> "fa-bolt"
    end
  end
end
