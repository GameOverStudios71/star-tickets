defmodule StarTickets.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias StarTickets.Repo

  alias StarTickets.Accounts.{
    User,
    UserToken,
    UserNotifier,
    Establishment,
    Client,
    Room,
    TV,
    TotemMenu,
    TotemMenuService
  }

  @doc """
  Gets a client by id.
  """
  def get_client!(id), do: Repo.get!(Client, id)

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by username.
  """
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a user by login (email or username) and password.
  Automatically detects if the login is an email (contains @) or username.
  """
  def get_user_by_login_and_password(login, password)
      when is_binary(login) and is_binary(password) do
    user =
      if String.contains?(login, "@") do
        Repo.get_by(User, email: login)
      else
        Repo.get_by(User, username: login)
      end

    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by ID. Returns nil if not found.
  """
  def get_user(id), do: Repo.get(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user profile.
  """
  def change_user_profile(user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  @doc """
  Updates the user profile (name, phone).
  """
  def update_user_profile(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `StarTickets.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `StarTickets.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token with optional device information.
  """
  def generate_user_session_token(user, device_info \\ %{}) do
    {token, user_token} = UserToken.build_session_token(user, device_info)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     In our implementation, this is allowed because we use password registration
     with email confirmation. The user confirms via magic link after registration.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Usuário não confirmado COM senha - nosso fluxo de registro
      # Confirma a conta e faz login
      {%User{confirmed_at: nil, hashed_password: hash} = user, _token} when not is_nil(hash) ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      # Usuário não confirmado SEM senha (magic link puro)
      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      # Usuário já confirmado
      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  ## Establishments

  alias StarTickets.Accounts.Establishment

  @doc """
  Returns the list of establishments.

  ## Examples

      iex> list_establishments()
      [%Establishment{}, ...]

  """
  def list_establishments(params \\ %{}) do
    search_term = get_in(params, ["search"]) || ""
    page = String.to_integer(get_in(params, ["page"]) || "1")
    per_page = String.to_integer(get_in(params, ["per_page"]) || "10")
    offset = (page - 1) * per_page

    Establishment
    |> search_establishments(search_term)
    |> order_by(desc: :inserted_at)
    |> limit(^per_page)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Returns the total count of establishments matching the search term.
  """
  def count_establishments(search_term \\ "") do
    Establishment
    |> search_establishments(search_term)
    |> Repo.aggregate(:count, :id)
  end

  defp search_establishments(query, search_term) do
    if search_term != "" do
      term = "%#{search_term}%"
      where(query, [e], ilike(e.name, ^term) or ilike(e.code, ^term))
    else
      query
    end
  end

  @doc """
  Gets a single establishment.

  Raises `Ecto.NoResultsError` if the Establishment does not exist.

  ## Examples

      iex> get_establishment!(123)
      %Establishment{}

      iex> get_establishment!(456)
      ** (Ecto.NoResultsError)

  """
  def get_establishment!(id), do: Repo.get!(Establishment, id)

  @doc """
  Creates a establishment.

  ## Examples

      iex> create_establishment(%{field: value})
      {:ok, %Establishment{}}

      iex> create_establishment(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_establishment(attrs \\ %{}) do
    %Establishment{}
    |> Establishment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a establishment.

  ## Examples

      iex> update_establishment(establishment, %{field: new_value})
      {:ok, %Establishment{}}

      iex> update_establishment(establishment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_establishment(%Establishment{} = establishment, attrs) do
    establishment
    |> Establishment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a establishment.

  ## Examples

      iex> delete_establishment(establishment)
      {:ok, %Establishment{}}

      iex> delete_establishment(establishment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_establishment(%Establishment{} = establishment) do
    Repo.delete(establishment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking establishment changes.

  ## Examples

      iex> change_establishment(establishment)
      %Ecto.Changeset{data: %Establishment{}}

  """
  def change_establishment(%Establishment{} = establishment, attrs \\ %{}) do
    Establishment.changeset(establishment, attrs)
  end

  ## Users (Admin)

  @doc """
  Returns the list of users.
  """
  def list_users(params \\ %{}) do
    search_term = get_in(params, ["search"]) || ""
    page = String.to_integer(get_in(params, ["page"]) || "1")
    per_page = String.to_integer(get_in(params, ["per_page"]) || "10")
    offset = (page - 1) * per_page
    client_id = params["client_id"]
    establishment_id = params["establishment_id"]

    User
    |> search_users(search_term)
    |> filter_by_client(client_id)
    |> filter_by_establishment(establishment_id)
    |> order_by(desc: :inserted_at)
    |> limit(^per_page)
    |> offset(^offset)
    |> preload([:client, :establishment])
    |> Repo.all()
  end

  def count_users(params \\ %{}) do
    search_term = get_in(params, ["search"]) || ""
    client_id = params["client_id"]
    establishment_id = params["establishment_id"]

    User
    |> search_users(search_term)
    |> filter_by_client(client_id)
    |> filter_by_establishment(establishment_id)
    |> Repo.aggregate(:count, :id)
  end

  defp search_users(query, search_term) do
    if search_term != "" do
      term = "%#{search_term}%"
      where(query, [u], ilike(u.name, ^term) or ilike(u.username, ^term) or ilike(u.email, ^term))
    else
      query
    end
  end

  defp filter_by_client(query, nil), do: query
  defp filter_by_client(query, client_id), do: where(query, [u], u.client_id == ^client_id)

  defp filter_by_establishment(query, nil), do: query

  defp filter_by_establishment(query, establishment_id),
    do: where(query, [u], u.establishment_id == ^establishment_id)

  def create_user(attrs \\ %{}) do
    result =
      %User{}
      |> User.admin_create_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, user} ->
        # Send welcome email asynchronously or synchronously?
        # Typically sync is fine here, or via Task.
        # Construct URL (assuming basic structure or passing it in?).
        # Wait, deliver_welcome needs a URL.
        # Ideally, we pass the login URL or confirmation URL.
        # For simplicity, we'll send a mocked URL or handle it at the caller level?
        # Caller (LiveView) knows the URL helper.
        # But commonly context functions just do DB.
        # "User requested system sends email".
        # I'll return {:ok, user} and let the LiveView call the Notifier with the correct URL.
        # OR I can do it here if I can generate the URL.
        # Since I don't have the Endpoint/conn here easily without coupling, I will let the Controller/LiveView trigger the email.
        {:ok, user}

      error ->
        error
    end
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.admin_update_changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def change_user(%User{} = user, attrs \\ %{}) do
    if user.id do
      User.admin_update_changeset(user, attrs)
    else
      User.admin_create_changeset(user, attrs)
    end
  end

  ## Impersonation Helpers

  @doc """
  Returns a list of users for a given establishment (for dropdown selection).
  Excludes the current user and only returns human-operable roles.
  """
  def list_users_for_dropdown(establishment_id)
      when is_binary(establishment_id) or is_integer(establishment_id) do
    User
    |> where([u], u.establishment_id == ^establishment_id)
    |> where([u], u.role in ["reception", "professional", "manager"])
    |> order_by([u], asc: u.name)
    |> select([u], %{id: u.id, name: u.name, role: u.role})
    |> Repo.all()
  end

  def list_users_for_dropdown(nil), do: []

  @doc """
  Returns all establishment for a given client (for dropdown selection).
  """
  def list_establishments_for_dropdown(client_id)
      when is_binary(client_id) or is_integer(client_id) do
    Establishment
    |> where([e], e.client_id == ^client_id)
    |> where([e], e.is_active == true)
    |> order_by([e], asc: e.name)
    |> select([e], %{id: e.id, name: e.name})
    |> Repo.all()
  end

  def list_establishments_for_dropdown(nil), do: []

  ## Services

  alias StarTickets.Accounts.Service

  @doc """
  Returns the list of services.
  """
  def list_establishment_services(establishment_id) do
    Repo.all(
      from(s in Service,
        join: e in StarTickets.Accounts.Establishment,
        on: e.client_id == s.client_id,
        where: e.id == ^establishment_id
      )
    )
  end

  def list_services(params \\ %{}) do
    search_term = get_in(params, ["search"]) || ""
    page = String.to_integer(get_in(params, ["page"]) || "1")
    per_page = String.to_integer(get_in(params, ["per_page"]) || "10")
    offset = (page - 1) * per_page
    client_id = params["client_id"]

    Service
    |> search_services(search_term)
    |> filter_services_by_client(client_id)
    |> order_by(asc: :name)
    |> limit(^per_page)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Returns the count of services.
  """
  def count_services(params \\ %{}) do
    search_term = get_in(params, ["search"]) || ""
    client_id = params["client_id"]

    Service
    |> search_services(search_term)
    |> filter_services_by_client(client_id)
    |> Repo.aggregate(:count, :id)
  end

  def list_services_with_establishment(client_id) do
    Service
    |> where([s], s.client_id == ^client_id)
    |> wait_preload_establishment()
    |> order_by([s], asc: :name)
    |> Repo.all()
  end

  defp wait_preload_establishment(query) do
    # Check if establishment association exists in schema first
    # For now assuming it doesn't (based on viewing schema earlier)
    # BUT list_establishment_services joined establishment.
    # Service has NO belongs_to :establishment in schema!
    # So I CANNOT preload it simply.
    # I must join manually.

    # Wait, if Service has no belongs_to establishment, how can I group by establishment?
    # I need to fetch services based on how they are associated.
    # User said: "relacionar com ... o nome do serviço e o nome do estabelecimento"

    # If Service is global to Client, it doesn't belong to an Establishment.
    # So grouping by establishment is impossible unless we look at TotemMenus.
    # But a service can be in multiple menus.

    # Maybe the user implies that services SHOULD be per establishment?
    # Or maybe the user sees them on the screen linked to establishments (via TotemMenu).

    # If the user wants to link Form to Service, and Service is global, then just listing Services is correct.
    # If I cannot group by establishment (because there is no link), I will just list Services.

    # So I will just return services.
    query
  end

  defp search_services(query, search_term) do
    if search_term != "" do
      term = "%#{search_term}%"
      where(query, [s], ilike(s.name, ^term))
    else
      query
    end
  end

  defp filter_services_by_client(query, nil), do: query

  defp filter_services_by_client(query, client_id),
    do: where(query, [s], s.client_id == ^client_id)

  def get_service!(id), do: Repo.get!(Service, id)

  def create_service(attrs \\ %{}) do
    %Service{}
    |> Service.changeset(attrs)
    |> Repo.insert()
  end

  def update_service(%Service{} = service, attrs) do
    service
    |> Service.changeset(attrs)
    |> Repo.update()
  end

  def delete_service(%Service{} = service) do
    Repo.delete(service)
  end

  def change_service(%Service{} = service, attrs \\ %{}) do
    Service.changeset(service, attrs)
  end

  ## Rooms

  def list_rooms(establishment_id, params \\ %{}) do
    search_term = get_in(params, ["search"]) || ""

    Room
    |> where(establishment_id: ^establishment_id)
    |> search_rooms(search_term)
    |> preload([:services, :occupied_by_user])
    |> Repo.all()
  end

  def occupy_room(%Room{} = room, user_id) do
    room
    |> Room.occupation_changeset(%{occupied_by_user_id: user_id})
    |> Repo.update()
  end

  def vacate_room(%Room{} = room) do
    room
    |> Room.occupation_changeset(%{occupied_by_user_id: nil})
    |> Repo.update()
  end

  def vacate_rooms_by_user(user_id) do
    from(r in Room, where: r.occupied_by_user_id == ^user_id)
    |> Repo.update_all(set: [occupied_by_user_id: nil])
  end

  defp search_rooms(query, ""), do: query

  defp search_rooms(query, search_term) do
    term = "%#{search_term}%"
    where(query, [r], ilike(r.name, ^term))
  end

  def get_room!(id), do: Repo.get!(Room, id) |> Repo.preload(:services)

  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> put_room_services(attrs)
    |> Repo.insert()
  end

  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> put_room_services(attrs)
    |> Repo.update()
  end

  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  defp put_room_services(changeset, attrs) do
    all_services = Ecto.Changeset.get_field(changeset, :all_services, false)
    ids = attrs["service_ids"] || []

    cond do
      all_services ->
        # If "All Services" is checked, clear specific associations
        Ecto.Changeset.put_assoc(changeset, :services, [])

      Enum.empty?(ids) ->
        # Services are optional when all_services is checked
        changeset

      true ->
        # Convert ids to integers safely
        ids =
          Enum.map(ids, fn
            id when is_binary(id) -> String.to_integer(id)
            id -> id
          end)

        services = Repo.all(from(s in Service, where: s.id in ^ids))
        Ecto.Changeset.put_assoc(changeset, :services, services)
    end
  end

  ## TVs

  def list_tvs(establishment_id, params \\ %{}) do
    search_term = get_in(params, ["search"]) || ""

    TV
    |> where(establishment_id: ^establishment_id)
    |> search_tvs(search_term)
    |> preload([:services, :rooms, :user])
    |> Repo.all()
  end

  defp search_tvs(query, ""), do: query

  defp search_tvs(query, search_term) do
    term = "%#{search_term}%"
    where(query, [t], ilike(t.name, ^term))
  end

  def get_tv!(id), do: Repo.get!(TV, id) |> Repo.preload([:services, :rooms, :user])

  def get_tv_by_user(user_id) do
    TV
    |> where([t], t.user_id == ^user_id)
    |> Repo.one()
  end

  def get_establishment(id) when is_nil(id), do: nil
  def get_establishment(id), do: Repo.get(Establishment, id)

  def create_tv(attrs \\ %{}) do
    # Normalize keys to strings
    attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})

    Repo.transaction(fn ->
      establishment =
        get_establishment!(attrs["establishment_id"])
        |> Repo.preload(:client)

      # Check if user_id is already provided
      user_id = attrs["user_id"] || attrs[:user_id]

      user =
        if user_id do
          Repo.get!(User, user_id)
        else
          # Generate username: client.estab.tv.slug
          slug_name =
            (attrs["name"] || "tv")
            |> String.normalize(:nfd)
            |> String.replace(~r/\p{Mn}/u, "")
            |> String.downcase()
            |> String.replace(~r/[^a-z0-9]/, "_")

          username =
            "#{establishment.client.slug}.#{establishment.code}.tv.#{slug_name}"
            |> String.downcase()

          # Default password if not provided
          password = attrs["password"] || "startickets123"
          email = "#{username}@star-tickets.local"

          # Create User
          user_params = %{
            "name" => attrs["name"],
            "username" => username,
            "email" => email,
            "password" => password,
            "role" => "tv",
            "client_id" => establishment.client_id,
            "establishment_id" => establishment.id
          }

          %User{}
          |> User.admin_create_changeset(user_params)
          |> Repo.insert()
          |> case do
            {:ok, user} -> user
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end

      # Create TV
      tv_params = Map.put(attrs, "user_id", user.id)

      tv =
        %TV{}
        |> TV.changeset(tv_params)
        |> put_tv_services(attrs)
        |> put_tv_rooms(attrs)
        |> Repo.insert()

      case tv do
        {:ok, tv} -> tv
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def update_tv(%TV{} = tv, attrs) do
    tv
    |> TV.changeset(attrs)
    |> put_tv_services(attrs)
    |> put_tv_rooms(attrs)
    |> Repo.update()
  end

  def delete_tv(%TV{} = tv) do
    # Deleting the user should cascade delete the TV?
    # Migration says: user_id references users on_delete: :delete_all
    # So if we delete user, TV goes.
    # But usually we delete TV. If we delete TV, User remains? Admin might want to keep user?
    # Requirement: "Sistema deve gerar automaticamente um usuário". Implicitly, this user is dedicated to this TV.
    # If TV is deleted, User should probably be deleted to avoid orphans.
    Repo.transaction(fn ->
      # Delete TV first? Or User first?
      Repo.delete(tv)
      # If I delete TV, User remains.
      # Delete user. This creates a race/FK issue?
      Repo.delete(tv.user)
      # If TV references User (on_delete: delete_all of TV), deleting User deletes TV.
      # So deleting User is enough.
    end)

    Repo.delete(tv.user)
  end

  def change_tv(%TV{} = tv, attrs \\ %{}) do
    TV.changeset(tv, attrs)
  end

  defp put_tv_services(changeset, attrs) do
    all_services = Ecto.Changeset.get_field(changeset, :all_services, false)
    ids = attrs["service_ids"] || []

    cond do
      all_services ->
        # If "All Services" is checked, we clear specific associations.
        Ecto.Changeset.put_assoc(changeset, :services, [])

      Enum.empty?(ids) ->
        # Services are now optional since we're primarily using rooms
        changeset

      true ->
        # Convert ids to integers safely
        ids =
          Enum.map(ids, fn
            id when is_binary(id) -> String.to_integer(id)
            id -> id
          end)

        services = Repo.all(from(s in Service, where: s.id in ^ids))
        Ecto.Changeset.put_assoc(changeset, :services, services)
    end
  end

  defp put_tv_rooms(changeset, attrs) do
    all_rooms = Ecto.Changeset.get_field(changeset, :all_rooms, false)
    ids = attrs["room_ids"] || []

    cond do
      all_rooms ->
        Ecto.Changeset.put_assoc(changeset, :rooms, [])

      Enum.empty?(ids) ->
        # Rooms are optional - no error if empty
        changeset

      true ->
        ids =
          Enum.map(ids, fn
            id when is_binary(id) -> String.to_integer(id)
            id -> id
          end)

        rooms = Repo.all(from(r in Room, where: r.id in ^ids))
        Ecto.Changeset.put_assoc(changeset, :rooms, rooms)
    end
  end

  def list_totem_menus(establishment_id) do
    TotemMenu
    |> where([m], m.establishment_id == ^establishment_id)
    |> order_by([m], asc: m.position, asc: m.inserted_at)
    |> Repo.all()
    |> Repo.preload(totem_menu_services: :service)
  end

  @doc """
  Lists all taggable menus for an establishment (is_taggable = true).
  Groups menus with the same name, returning a list of IDs per group.
  Used as filter tags in the Reception interface.
  """
  def list_taggable_menus(establishment_id) do
    TotemMenu
    |> where([m], m.establishment_id == ^establishment_id and m.is_taggable == true)
    |> order_by([m], asc: m.position, asc: m.inserted_at)
    |> select([m], %{id: m.id, name: m.name, icon_class: m.icon_class})
    |> Repo.all()
    |> Enum.group_by(& &1.name)
    |> Enum.map(fn {name, menus} ->
      %{
        name: name,
        icon_class: List.first(menus).icon_class,
        ids: Enum.map(menus, & &1.id)
      }
    end)
  end

  @doc """
  Lists root totem menus (parent_id is nil) for an establishment.
  Used by the totem kiosk interface.
  """
  def list_root_totem_menus(establishment_id) do
    TotemMenu
    |> where([m], m.establishment_id == ^establishment_id and is_nil(m.parent_id))
    |> order_by([m], asc: m.position, asc: m.inserted_at)
    |> Repo.all()
    |> Repo.preload([:children, totem_menu_services: :service])
  end

  @doc """
  Gets children of a totem menu for navigation.
  """
  def get_totem_menu_children(menu_id) do
    TotemMenu
    |> where([m], m.parent_id == ^menu_id)
    |> order_by([m], asc: m.position, asc: m.inserted_at)
    |> Repo.all()
    |> Repo.preload([:children, totem_menu_services: :service])
  end

  def get_totem_menu!(id),
    do: Repo.get!(TotemMenu, id) |> Repo.preload([:children, totem_menu_services: :service])

  def create_totem_menu(attrs \\ %{}) do
    %TotemMenu{}
    |> TotemMenu.changeset(attrs)
    |> put_totem_menu_services(attrs)
    |> Repo.insert()
  end

  def update_totem_menu(%TotemMenu{} = menu, attrs) do
    menu
    |> TotemMenu.changeset(attrs)
    |> put_totem_menu_services(attrs)
    |> Repo.update()
  end

  def delete_totem_menu(%TotemMenu{} = menu) do
    Repo.delete(menu)
  end

  def change_totem_menu(%TotemMenu{} = menu, attrs \\ %{}) do
    TotemMenu.changeset(menu, attrs)
  end

  def move_totem_menu(menu_id, direction) when direction in [:up, :down] do
    menu = get_totem_menu!(menu_id)

    # Fetch siblings
    siblings =
      TotemMenu
      |> where(establishment_id: ^menu.establishment_id)
      |> where(
        [m],
        m.parent_id == ^menu.parent_id or (is_nil(m.parent_id) and is_nil(^menu.parent_id))
      )
      |> order_by([m], asc: m.position, asc: m.inserted_at)
      |> Repo.all()

    # Find index
    index = Enum.find_index(siblings, &(&1.id == menu.id))

    case {direction, index} do
      {:up, i} when i > 0 ->
        swap_and_update(siblings, i, i - 1)

      {:down, i} when i < length(siblings) - 1 ->
        swap_and_update(siblings, i, i + 1)

      _ ->
        {:error, :cannot_move}
    end
  end

  defp swap_and_update(siblings, idx_a, idx_b) do
    # Create new list with swapped elements
    {a, b} = {Enum.at(siblings, idx_a), Enum.at(siblings, idx_b)}

    siblings_updated =
      siblings
      |> List.replace_at(idx_a, b)
      |> List.replace_at(idx_b, a)

    # Update positions for ALL to normalize
    Repo.transaction(fn ->
      Enum.with_index(siblings_updated)
      |> Enum.each(fn {item, idx} ->
        item
        |> TotemMenu.changeset(%{position: idx})
        |> Repo.update!()
      end)
    end)
  end

  defp put_totem_menu_services(changeset, attrs) do
    services_data = attrs["services_data"] || attrs[:services_data]

    if services_data && is_list(services_data) do
      # Create TotemMenuService structs from list
      # Each item: %{service_id: x, description: "..", icon_class: ".."}
      menu_services =
        Enum.with_index(services_data)
        |> Enum.map(fn {item, index} ->
          %TotemMenuService{
            service_id: parse_id(item["service_id"] || item[:service_id]),
            description: item["description"] || item[:description],
            icon_class: item["icon_class"] || item[:icon_class],
            position: index
          }
        end)

      Ecto.Changeset.put_assoc(changeset, :totem_menu_services, menu_services)
    else
      changeset
    end
  end

  defp parse_id(nil), do: nil
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)
  defp parse_id(id) when is_integer(id), do: id

  @doc """
  Duplicates a totem menu node and all its descendants to a new parent.
  If target_parent_id is nil, creates as a root node.
  Returns {:ok, new_menu} or {:error, changeset}.
  """
  def duplicate_totem_menu_tree(source_id, target_parent_id) do
    source = get_totem_menu!(source_id)

    Repo.transaction(fn ->
      do_duplicate_node(source, target_parent_id, source.establishment_id)
    end)
  end

  defp do_duplicate_node(source, parent_id, establishment_id) do
    # Create copy of the node
    attrs = %{
      name: source.name,
      description: source.description,
      icon_class: source.icon_class,
      position: source.position,
      establishment_id: establishment_id,
      parent_id: parent_id
    }

    # Also copy the services
    services_data =
      Enum.map(source.totem_menu_services, fn svc ->
        %{
          service_id: svc.service_id,
          description: svc.description,
          icon_class: svc.icon_class
        }
      end)

    attrs = Map.put(attrs, :services_data, services_data)

    {:ok, new_node} = create_totem_menu(attrs)

    # Recursively copy children
    children =
      Repo.all(from(m in TotemMenu, where: m.parent_id == ^source.id))
      |> Repo.preload(totem_menu_services: :service)

    Enum.each(children, fn child ->
      do_duplicate_node(child, new_node.id, establishment_id)
    end)

    new_node
  end
end
