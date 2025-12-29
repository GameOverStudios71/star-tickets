defmodule StarTickets.Tickets.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tickets" do
    field(:display_code, :string)
    field(:status, :string, default: "pending")
    field(:token, Ecto.UUID)
    field(:customer_name, :string)

    belongs_to(:establishment, StarTickets.Accounts.Establishment)
    belongs_to(:user, StarTickets.Accounts.User)

    many_to_many(:services, StarTickets.Accounts.Service,
      join_through: "tickets_services",
      on_replace: :delete
    )

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:display_code, :status, :token, :establishment_id, :user_id, :customer_name])
    |> validate_required([:display_code, :establishment_id, :token])
    |> unique_constraint(:token)
  end
end
