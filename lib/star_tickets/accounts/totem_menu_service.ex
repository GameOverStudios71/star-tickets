defmodule StarTickets.Accounts.TotemMenuService do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "totem_menu_services" do
    field(:description, :string)
    field(:icon_class, :string)
    field(:position, :integer, default: 0)

    belongs_to(:totem_menu, StarTickets.Accounts.TotemMenu, primary_key: true)
    belongs_to(:service, StarTickets.Accounts.Service, primary_key: true)
  end

  @doc false
  def changeset(totem_menu_service, attrs) do
    totem_menu_service
    |> cast(attrs, [:totem_menu_id, :service_id, :description, :icon_class, :position])
    |> validate_required([:totem_menu_id, :service_id])
  end
end
