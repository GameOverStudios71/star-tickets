defmodule StarTickets.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:confirmed_at, :utc_datetime)
    field(:authenticated_at, :utc_datetime, virtual: true)

    # Multi-tenant fields
    field(:name, :string)
    field(:username, :string)
    field(:phone_number, :string)
    field(:role, :string, default: "professional")

    belongs_to(:client, StarTickets.Accounts.Client)
    belongs_to(:establishment, StarTickets.Accounts.Establishment)

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset =
        changeset
        |> unsafe_validate_unique(:email, StarTickets.Repo)
        |> unique_constraint(:email)

      # Skip "did not change" check for admin updates
      if Keyword.get(opts, :skip_email_changed_check, false) do
        changeset
      else
        validate_email_changed(changeset)
      end
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%StarTickets.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  A user changeset for admin creation.
  """
  def admin_create_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :username,
      :email,
      :password,
      :role,
      :client_id,
      :establishment_id,
      :phone_number
    ])
    |> validate_required([:name, :username, :email, :password, :role, :client_id])
    |> validate_email([])
    |> validate_password([])
    |> validate_inclusion(:role, ~w(reception professional manager tv totem admin))
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:establishment_id)
  end

  @doc """
  A user changeset for admin update.
  """
  def admin_update_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :username,
      :email,
      :password,
      :role,
      :client_id,
      :establishment_id,
      :phone_number
    ])
    |> validate_required([:name, :username, :email, :role, :client_id])
    |> validate_email(skip_email_changed_check: true)
    |> validate_inclusion(:role, ~w(reception professional manager tv totem admin))
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:establishment_id)
    |> case do
      %{changes: %{password: _}} = changeset -> validate_password(changeset, [])
      changeset -> changeset
    end
  end

  def roles, do: ~w(reception professional manager tv totem admin)
end
