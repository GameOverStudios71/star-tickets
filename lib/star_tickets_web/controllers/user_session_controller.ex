defmodule StarTicketsWeb.UserSessionController do
  use StarTicketsWeb, :controller

  alias StarTickets.Accounts
  alias StarTickets.Audit
  alias StarTicketsWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        # Log successful login
        Audit.log_action(
          "USER_LOGIN",
          %{
            resource_type: "User",
            resource_id: to_string(user.id),
            details: %{method: "magic_link"}
          },
          user
        )

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        # Log failed login attempt
        Audit.log_action("USER_LOGIN_FAILED", %{
          resource_type: "User",
          details: %{method: "magic_link", reason: "invalid_or_expired"}
        })

        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # login (email or username) + password login
  defp create(conn, %{"user" => user_params}, info) do
    password = user_params["password"]
    login = user_params["login"] || user_params["email"]

    user = login && password && Accounts.get_user_by_login_and_password(login, password)

    if user do
      # Log successful login
      Audit.log_action(
        "USER_LOGIN",
        %{
          resource_type: "User",
          resource_id: to_string(user.id),
          details: %{method: "password", login: login}
        },
        user
      )

      conn =
        case info do
          {kind, msg} -> put_flash(conn, kind, msg)
          msg when is_binary(msg) -> put_flash(conn, :info, msg)
          _ -> conn
        end

      UserAuth.log_in_user(conn, user, user_params)
    else
      # Log failed login attempt
      Audit.log_action("USER_LOGIN_FAILED", %{
        resource_type: "User",
        details: %{method: "password", login: login, reason: "invalid_credentials"}
      })

      # In order to prevent user enumeration attacks, don't disclose whether the login is registered.
      conn
      |> put_flash(:error, "Email/usuário ou senha inválidos")
      |> put_flash(:login, String.slice(login || "", 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, {:success, "Sua senha foi alterada com sucesso!"})
  end

  def delete(conn, _params) do
    user = conn.assigns[:current_user] || conn.assigns[:current_scope][:user]

    # Log logout
    if user do
      Audit.log_action(
        "USER_LOGOUT",
        %{
          resource_type: "User",
          resource_id: to_string(user.id)
        },
        user
      )
    end

    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
