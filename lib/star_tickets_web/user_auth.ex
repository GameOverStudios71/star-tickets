defmodule StarTicketsWeb.UserAuth do
  use StarTicketsWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias StarTickets.Accounts
  alias StarTickets.Accounts.Scope

  # Make the remember me cookie valid for 14 days. This should match
  # the session validity setting in UserToken.
  @max_cookie_age_in_days 14
  @remember_me_cookie "_star_tickets_web_user_remember_me"
  @remember_me_options [
    sign: true,
    max_age: @max_cookie_age_in_days * 24 * 60 * 60,
    same_site: "Lax"
  ]

  # How old the session token should be before a new one is issued. When a request is made
  # with a session token older than this value, then a new session token will be created
  # and the session and remember-me cookies (if set) will be updated with the new token.
  # Lowering this value will result in more tokens being created by active users. Increasing
  # it will result in less time before a session token expires for a user to get issued a new
  # token. This can be set to a value greater than `@max_cookie_age_in_days` to disable
  # the reissuing of tokens completely.
  @session_reissue_age_in_days 7

  @doc """
  Logs the user in.

  Redirects to the session's `:user_return_to` path
  or falls back to the `signed_in_path/1`.
  """
  def log_in_user(conn, user, params \\ %{}) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> create_or_extend_session(user, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      StarTicketsWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session(nil)
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/users/log-in")
  end

  @doc """
  Authenticates the user by looking into the session and remember me token.

  Will reissue the session token if it is older than the configured age.
  Also checks for impersonation session to support admin/manager user switching.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    with {token, conn} <- ensure_user_token(conn),
         {user, token_inserted_at} <- Accounts.get_user_by_session_token(token) do
      # Check for impersonation
      scope =
        case get_session(conn, :impersonated_user_id) do
          nil ->
            Scope.for_user(user)

          impersonated_user_id ->
            case Accounts.get_user(impersonated_user_id) do
              nil ->
                # Invalid impersonation, clear it
                Scope.for_user(user)

              impersonated_user ->
                # Valid impersonation
                Scope.for_impersonation(user, impersonated_user)
            end
        end

      conn
      |> assign(:current_scope, scope)
      |> maybe_reissue_user_session_token(user, token_inserted_at)
    else
      nil -> assign(conn, :current_scope, Scope.for_user(nil))
    end
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, conn |> put_token_in_session(token) |> put_session(:user_remember_me, true)}
      else
        nil
      end
    end
  end

  # Reissue the session token if it is older than the configured reissue age.
  defp maybe_reissue_user_session_token(conn, user, token_inserted_at) do
    token_age = DateTime.diff(DateTime.utc_now(:second), token_inserted_at, :day)

    if token_age >= @session_reissue_age_in_days do
      create_or_extend_session(conn, user, %{})
    else
      conn
    end
  end

  # This function is the one responsible for creating session tokens
  # and storing them safely in the session and cookies. It may be called
  # either when logging in, during sudo mode, or to renew a session which
  # will soon expire.
  #
  # When the session is created, rather than extended, the renew_session
  # function will clear the session to avoid fixation attacks. See the
  # renew_session function to customize this behaviour.
  defp create_or_extend_session(conn, user, params) do
    # Extract device information from the request
    device_info = extract_device_info(conn)

    token = Accounts.generate_user_session_token(user, device_info)
    remember_me = get_session(conn, :user_remember_me)

    conn
    |> renew_session(user)
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params, remember_me)
  end

  defp extract_device_info(conn) do
    alias StarTickets.Accounts.Devices

    user_agent = get_req_header(conn, "user-agent") |> List.first() || ""
    ip_address = get_client_ip(conn)

    Devices.parse_user_agent(user_agent)
    |> Map.put(:ip_address, ip_address)
  end

  defp get_client_ip(conn) do
    # Try X-Forwarded-For header first (for proxies/load balancers)
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded |> String.split(",") |> List.first() |> String.trim()

      [] ->
        # Fall back to remote_ip
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end

  # Do not renew session if the user is already logged in
  # to prevent CSRF errors or data being lost in tabs that are still open
  defp renew_session(conn, user) when conn.assigns.current_scope.user.id == user.id do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn, _user) do
  #       delete_csrf_token()
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn, _user) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}, _),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, token, _params, true),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, _token, _params, _), do: conn

  defp write_remember_me_cookie(conn, token) do
    conn
    |> put_session(:user_remember_me, true)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, user_session_topic(token))
  end

  @doc """
  Disconnects existing sockets for the given tokens.
  """
  def disconnect_sessions(tokens) do
    Enum.each(tokens, fn %{token: token} ->
      StarTicketsWeb.Endpoint.broadcast(user_session_topic(token), "disconnect", %{})
    end)
  end

  defp user_session_topic(token), do: "users_sessions:#{Base.url_encode64(token)}"

  @doc """
  Handles mounting and authenticating the current_scope in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_scope` - Assigns current_scope
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:require_authenticated` - Authenticates the user from the session,
      and assigns the current_scope to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the `current_scope`:

      defmodule StarTicketsWeb.PageLive do
        use StarTicketsWeb, :live_view

        on_mount {StarTicketsWeb.UserAuth, :mount_current_scope}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{StarTicketsWeb.UserAuth, :require_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:halt, socket}
    end
  end

  def on_mount(:require_sudo_mode, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if Accounts.sudo_mode?(socket.assigns.current_scope.user, -10) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must re-authenticate to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:halt, socket}
    end
  end

  # Role-based access control hooks
  alias StarTicketsWeb.Authorization

  @doc """
  Requires the user to have admin role.
  Use in live_session for /admin/* routes.
  """
  def on_mount(:require_admin, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    check_role_access(socket, :admin)
  end

  @doc """
  Requires the user to have dashboard access.
  Allows admin, manager, reception, and professional roles.
  """
  def on_mount(:require_dashboard, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    check_role_access(socket, :dashboard)
  end

  @doc """
  Requires the user to have manager or admin role.
  """
  def on_mount(:require_manager, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    check_role_access(socket, :manager)
  end

  @doc """
  Requires the user to have reception access.
  """
  def on_mount(:require_reception, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    check_role_access(socket, :reception)
  end

  @doc """
  Requires the user to have professional access.
  """
  def on_mount(:require_professional, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    check_role_access(socket, :professional)
  end

  @doc """
  Requires the user to have TV panel access.
  """
  def on_mount(:require_tv, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    check_role_access(socket, :tv)
  end

  @doc """
  Requires the user to have totem access.
  """
  def on_mount(:require_totem, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    check_role_access(socket, :totem)
  end

  def on_mount(:ensure_authenticated, params, session, socket) do
    on_mount(:require_authenticated, params, session, socket)
  end

  def on_mount(:ensure_admin_or_manager, _params, session, socket) do
    socket = mount_current_scope(socket, session)
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if user && (user.role == "admin" || user.role == "manager") do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Você não tem permissão para acessar esta página.")
        |> Phoenix.LiveView.redirect(to: get_default_path_for_role(user && user.role))

      {:halt, socket}
    end
  end

  defp check_role_access(socket, route_key) do
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if user && Authorization.can_access?(user.role, route_key) do
      {:cont, socket}
    else
      # Get the first route the user CAN access
      redirect_path = get_default_path_for_role(user && user.role)

      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Você não tem permissão para acessar esta página.")
        |> Phoenix.LiveView.redirect(to: redirect_path)

      {:halt, socket}
    end
  end

  defp get_default_path_for_role("admin"), do: ~p"/dashboard"
  defp get_default_path_for_role("manager"), do: ~p"/dashboard"
  defp get_default_path_for_role("reception"), do: ~p"/reception"
  defp get_default_path_for_role("professional"), do: ~p"/professional"
  defp get_default_path_for_role("tv"), do: ~p"/tv"
  defp get_default_path_for_role("totem"), do: ~p"/totem"
  defp get_default_path_for_role(_), do: ~p"/users/log-in"

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      {user, _} =
        if user_token = session["user_token"] do
          Accounts.get_user_by_session_token(user_token)
        end || {nil, nil}

      if user do
        # Check for impersonation in session
        case session["impersonated_user_id"] do
          nil ->
            Scope.for_user(user)

          impersonated_user_id ->
            case Accounts.get_user(impersonated_user_id) do
              nil ->
                # Invalid impersonation, use normal user
                Scope.for_user(user)

              impersonated_user ->
                # Valid impersonation
                Scope.for_impersonation(user, impersonated_user)
            end
        end
      else
        Scope.for_user(nil)
      end
    end)
  end

  @doc "Returns the path to redirect to after log in based on user role."
  def signed_in_path(%Plug.Conn{
        assigns: %{current_scope: %Scope{user: %Accounts.User{role: role}}}
      }) do
    get_default_path_for_role(role)
  end

  def signed_in_path(_), do: ~p"/users/log-in"

  @doc """
  Plug for routes that require the user to be authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end
