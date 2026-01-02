defmodule StarTicketsWeb.ImpersonationHelpers do
  @moduledoc """
  Helper functions for loading impersonation data for headers.
  Used by multiple LiveViews to show user switching dropdown.
  """

  alias StarTickets.Accounts
  alias StarTickets.Accounts.Scope

  @doc """
  Loads impersonation-related assigns for a LiveView socket.
  Returns a map of assigns to be merged into the socket.

  ## Usage in LiveView mount:
      assigns = ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)
      {:ok, assign(socket, assigns)}
  """
  def load_impersonation_assigns(scope, session \\ %{}) do
    user = scope.user
    real_user = Scope.get_real_user(scope) || user

    can_impersonate = real_user.role in ["admin", "manager"]

    # Load client
    client = if real_user.client_id, do: Accounts.get_client!(real_user.client_id), else: nil

    # Load establishments for admin
    establishments =
      if real_user.role == "admin" do
        Accounts.list_establishments_for_dropdown(real_user.client_id)
      else
        []
      end

    # Determine which establishment to use for user list
    # Priority: session saved > real_user's > first available
    session_establishment_id = session["selected_establishment_id"]

    establishment_for_users =
      cond do
        session_establishment_id != nil ->
          session_establishment_id

        real_user.establishment_id != nil ->
          real_user.establishment_id

        real_user.role == "admin" and establishments != [] ->
          hd(establishments).id

        true ->
          nil
      end

    # Load establishment info (handle case where establishment was deleted)
    establishment =
      if establishment_for_users do
        try do
          Accounts.get_establishment!(establishment_for_users)
        rescue
          Ecto.NoResultsError -> nil
        end
      else
        nil
      end

    # If establishment was invalid, reset to nil
    establishment_for_users = if establishment, do: establishment_for_users, else: nil

    # Load users for the selected establishment
    users =
      if can_impersonate and establishment_for_users != nil do
        Accounts.list_users_for_dropdown(establishment_for_users)
      else
        []
      end

    %{
      can_impersonate: can_impersonate,
      client: client,
      client_name: client && client.name,
      establishment: establishment,
      establishment_name: establishment && establishment.name,
      establishments: establishments,
      users: users,
      selected_establishment_id: establishment_for_users,
      selected_user_id: if(Scope.impersonating?(scope), do: user.id, else: nil),
      impersonating: Scope.impersonating?(scope)
    }
  end
end
