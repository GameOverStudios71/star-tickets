defmodule StarTickets.Forms.FormResponse do
  use Ecto.Schema
  import Ecto.Changeset

  schema "form_responses" do
    field(:value, :string)
    belongs_to(:ticket, StarTickets.Tickets.Ticket)
    belongs_to(:form_field, StarTickets.Forms.FormField)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(form_response, attrs) do
    form_response
    |> cast(attrs, [:value, :ticket_id, :form_field_id])
    |> validate_required([:value, :ticket_id, :form_field_id])
  end
end
