defmodule StarTickets.Accounts.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field(:name, :string)
    field(:capacity_threshold, :integer, default: 0)
    belongs_to(:establishment, StarTickets.Accounts.Establishment)

    many_to_many(:services, StarTickets.Accounts.Service,
      join_through: "room_services",
      on_replace: :delete
    )

    belongs_to(:occupied_by_user, StarTickets.Accounts.User)

    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :capacity_threshold, :establishment_id])
    |> validate_required([:name, :establishment_id])
  end

  def occupation_changeset(room, attrs) do
    room
    |> cast(attrs, [:occupied_by_user_id])
  end
end
