defmodule StarTickets.Accounts.TotemMenu do
  use Ecto.Schema
  import Ecto.Changeset

  schema "totem_menus" do
    field(:name, :string)
    field(:description, :string)
    field(:icon_class, :string)
    field(:type, Ecto.Enum, values: [:tag, :category])
    field(:position, :integer, default: 0)

    belongs_to(:establishment, StarTickets.Accounts.Establishment)
    belongs_to(:parent, StarTickets.Accounts.TotemMenu)
    has_many(:children, StarTickets.Accounts.TotemMenu, foreign_key: :parent_id)

    has_many(:totem_menu_services, StarTickets.Accounts.TotemMenuService, on_replace: :delete)
    has_many(:services, through: [:totem_menu_services, :service])

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(totem_menu, attrs) do
    totem_menu
    |> cast(attrs, [
      :name,
      :type,
      :position,
      :establishment_id,
      :parent_id,
      :description,
      :icon_class
    ])
    |> validate_required([:name, :type, :establishment_id])
  end
end
