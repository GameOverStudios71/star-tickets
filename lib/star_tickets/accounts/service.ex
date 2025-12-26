defmodule StarTickets.Accounts.Service do
  use Ecto.Schema
  import Ecto.Changeset

  schema "services" do
    field(:name, :string)
    # minutes
    field(:duration, :integer)

    belongs_to(:client, StarTickets.Accounts.Client)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(service, attrs) do
    service
    |> cast(attrs, [:name, :duration, :client_id])
    |> validate_required([:name, :duration, :client_id])
    |> validate_number(:duration, greater_than: 0, message: "deve ser maior que zero")
    |> foreign_key_constraint(:client_id)
  end
end
