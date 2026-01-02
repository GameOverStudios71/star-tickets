defmodule StarTickets.Tickets.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :display_code,
             :status,
             :token,
             :customer_name,
             :is_priority,
             :health_insurance_name,
             :webcheckin_status,
             :webcheckin_started_at,
             :webcheckin_completed_at,
             :establishment_id,
             :user_id,
             :room_id,
             :inserted_at,
             :updated_at
           ]}
  schema "tickets" do
    field(:display_code, :string)
    field(:status, :string, default: "WAITING_RECEPTION")
    field(:token, Ecto.UUID)
    field(:customer_name, :string)

    field(:is_priority, :boolean, default: false)
    field(:health_insurance_name, :string)

    # PENDING, IN_PROGRESS, COMPLETED, REVIEWED
    field(:webcheckin_status, :string)
    field(:webcheckin_token, :string)
    field(:webcheckin_started_at, :utc_datetime)
    field(:webcheckin_completed_at, :utc_datetime)
    field(:webcheckin_token_expires_at, :utc_datetime)

    belongs_to(:establishment, StarTickets.Accounts.Establishment)
    belongs_to(:user, StarTickets.Accounts.User)
    belongs_to(:room, StarTickets.Accounts.Room)

    many_to_many(:services, StarTickets.Accounts.Service,
      join_through: "tickets_services",
      on_replace: :delete
    )

    has_many(:form_responses, StarTickets.Forms.FormResponse)

    many_to_many(:tags, StarTickets.Accounts.TotemMenu,
      join_through: "tickets_tags",
      on_replace: :delete
    )

    # has_many :webcheckin_files, StarTickets.Forms.WebCheckinFile # Schema needs to be created or checked

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [
      :display_code,
      :status,
      :token,
      :establishment_id,
      :user_id,
      :customer_name,
      :room_id,
      :is_priority,
      :health_insurance_name,
      :webcheckin_status,
      :webcheckin_token,
      :webcheckin_started_at,
      :webcheckin_completed_at,
      :webcheckin_token_expires_at
    ])
    |> validate_required([:display_code, :establishment_id, :token])
    |> unique_constraint(:token)
  end
end
