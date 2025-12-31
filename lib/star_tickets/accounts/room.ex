defmodule StarTickets.Accounts.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field(:name, :string)
    # "reception" | "professional" | "both"
    field(:type, :string, default: "professional")
    field(:is_active, :boolean, default: true)
    field(:capacity_threshold, :integer, default: 0)
    field(:all_services, :boolean, default: false)

    belongs_to(:establishment, StarTickets.Accounts.Establishment)
    belongs_to(:occupied_by_user, StarTickets.Accounts.User)

    many_to_many(:services, StarTickets.Accounts.Service,
      join_through: "room_services",
      on_replace: :delete
    )

    has_many(:tickets, StarTickets.Tickets.Ticket)

    timestamps()
  end

  @room_types ~w(reception professional both)

  def changeset(room, attrs) do
    room
    |> cast(attrs, [
      :name,
      :type,
      :is_active,
      :capacity_threshold,
      :establishment_id,
      :all_services
    ])
    |> validate_required([:name, :establishment_id])
    |> validate_inclusion(:type, @room_types)
  end

  def occupation_changeset(room, attrs) do
    room
    |> cast(attrs, [:occupied_by_user_id])
  end

  def types, do: @room_types
end
