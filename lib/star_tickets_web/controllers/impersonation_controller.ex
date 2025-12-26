defmodule StarTicketsWeb.ImpersonationController do
  @moduledoc """
  Controller for managing user impersonation.
  Allows admins and managers to impersonate other users.
  """
  use StarTicketsWeb, :controller

  alias StarTickets.Accounts
  alias StarTickets.Accounts.Scope

  @doc """
  Sets the impersonated user in session.
  Only admin and manager roles can impersonate.
  """
  def create(conn, %{"user_id" => user_id}) do
    scope = conn.assigns.current_scope
    # Get the real logged-in user (not impersonated one)
    real_user = Scope.get_real_user(scope) || scope.user

    cond do
      real_user.role not in ["admin", "manager"] ->
        conn
        |> put_flash(:error, "Você não tem permissão para impersonar usuários.")
        |> redirect(to: ~p"/dashboard")

      user_id == "" || user_id == nil ->
        # Clear impersonation
        conn
        |> delete_session(:impersonated_user_id)
        |> put_flash(:info, "Impersonação removida.")
        |> redirect(to: ~p"/dashboard")

      true ->
        case Accounts.get_user(user_id) do
          nil ->
            conn
            |> put_flash(:error, "Usuário não encontrado.")
            |> redirect(to: ~p"/dashboard")

          target_user ->
            # Validate: cannot impersonate admin (unless you are admin)
            cond do
              target_user.id == real_user.id ->
                # Selecting self = exit impersonation
                conn
                |> delete_session(:impersonated_user_id)
                |> put_flash(:info, "Voltando para sua conta.")
                |> redirect(to: ~p"/dashboard")

              target_user.role == "admin" and real_user.role != "admin" ->
                conn
                |> put_flash(:error, "Você não pode impersonar um administrador.")
                |> redirect(to: ~p"/dashboard")

              true ->
                redirect_path =
                  case target_user.role do
                    "reception" -> ~p"/reception"
                    "professional" -> ~p"/professional"
                    _ -> ~p"/dashboard"
                  end

                conn
                |> put_session(:impersonated_user_id, target_user.id)
                |> put_flash(:info, "Agora navegando como #{target_user.name}.")
                |> redirect(to: redirect_path)
            end
        end
    end
  end

  @doc """
  Clears the impersonation from session.
  """
  def delete(conn, _params) do
    conn
    |> delete_session(:impersonated_user_id)
    |> put_flash(:info, "Impersonação removida.")
    |> redirect(to: ~p"/dashboard")
  end

  @doc """
  Sets the selected establishment in session (for admin).
  """
  def select_establishment(conn, %{"establishment_id" => establishment_id}) do
    conn
    |> put_session(:selected_establishment_id, establishment_id)
    |> redirect(to: ~p"/dashboard")
  end
end
