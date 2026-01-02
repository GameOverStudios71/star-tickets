defmodule StarTicketsWeb.Authorization do
  @moduledoc """
  Role-based access control (RBAC) module.
  Defines permission rules for each user role.
  """

  # Permission matrix: maps roles to allowed route keys.
  # :all means the role can access everything.
  @permissions %{
    "admin" => [:all],
    "manager" => [:dashboard, :manager, :reception, :professional, :tv, :totem, :settings],
    "reception" => [:dashboard, :reception, :settings],
    "professional" => [:dashboard, :professional, :settings],
    "tv" => [:tv],
    "totem" => [:totem]
  }

  # List of all route keys for reference.
  @route_keys [:dashboard, :admin, :manager, :reception, :professional, :tv, :totem, :settings]

  @doc """
  Check if a user role can access a specific route.

  ## Examples

      iex> can_access?("admin", :reception)
      true

      iex> can_access?("reception", :admin)
      false

      iex> can_access?("totem", :totem)
      true
  """
  def can_access?(role, route_key) when is_binary(role) and is_atom(route_key) do
    perms = Map.get(@permissions, role, [])
    :all in perms or route_key in perms
  end

  def can_access?(nil, _route_key), do: false

  @doc """
  Returns the list of allowed route keys for a given role.
  """
  def allowed_routes(role) when is_binary(role) do
    perms = Map.get(@permissions, role, [])

    if :all in perms do
      @route_keys
    else
      perms
    end
  end

  def allowed_routes(nil), do: []

  @doc """
  Returns all available route keys.
  """
  def all_route_keys, do: @route_keys

  @doc """
  Returns menu items filtered by user role.
  """
  def menu_items_for_role(role) do
    all_menu_items()
    |> Enum.filter(fn item -> can_access?(role, item.key) end)
  end

  defp all_menu_items do
    [
      %{label: "Dashboard", href: "/dashboard", key: :dashboard, icon: "hero-squares-2x2"},
      %{label: "Administração", href: "/admin", key: :admin, icon: "hero-cog-6-tooth"},
      %{label: "Gestão", href: "/manager", key: :manager, icon: "hero-chart-bar"},
      %{label: "Recepção", href: "/reception", key: :reception, icon: "hero-ticket"},
      %{label: "Profissional", href: "/professional", key: :professional, icon: "hero-user"},
      %{label: "Painel TV", href: "/tv", key: :tv, icon: "hero-tv"},
      %{label: "Totem", href: "/totem", key: :totem, icon: "hero-computer-desktop"}
    ]
  end
end
