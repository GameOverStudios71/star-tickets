defmodule StarTickets.Reception.ReceptionDesk do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reception_desks" do
    field(:name, :string)
    field(:is_active, :boolean, default: true)

    belongs_to(:establishment, StarTickets.Accounts.Establishment)
    belongs_to(:occupied_by_user, StarTickets.Accounts.User)
    has_many(:tickets, StarTickets.Tickets.Ticket)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(reception_desk, attrs) do
    reception_desk
    |> cast(attrs, [:name, :is_active, :establishment_id])
    |> validate_required([:name, :establishment_id])
  end

  def occupation_changeset(reception_desk, attrs) do
    reception_desk
    |> cast(attrs, [:occupied_by_user_id])
  end
end
