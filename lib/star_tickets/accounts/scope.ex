defmodule StarTickets.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `StarTickets.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  ## Impersonation Support
  When an admin or manager impersonates another user:
  - `user` contains the impersonated user (for permission checks)
  - `real_user` contains the actual logged-in admin/manager (for audit logs)
  """

  alias StarTickets.Accounts.User

  defstruct user: nil, real_user: nil

  @doc """
  Creates a scope for the given user.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user, real_user: nil}
  end

  def for_user(nil), do: nil

  @doc """
  Creates a scope for impersonation.
  `real_user` is the admin/manager who is impersonating.
  `impersonated_user` is the user being impersonated.
  """
  def for_impersonation(%User{} = real_user, %User{} = impersonated_user) do
    %__MODULE__{user: impersonated_user, real_user: real_user}
  end

  @doc """
  Returns true if the scope represents an impersonation session.
  """
  def impersonating?(%__MODULE__{real_user: real_user}) when not is_nil(real_user), do: true
  def impersonating?(_), do: false

  @doc """
  Returns the real user (the one who logged in and is impersonating).
  Returns nil if not impersonating.
  """
  def get_real_user(%__MODULE__{real_user: real_user}), do: real_user
  def get_real_user(_), do: nil
end
