defmodule StarTickets.Accounts.Service do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :description,
             :duration,
             :client_id,
             :form_template_id,
             :inserted_at,
             :updated_at
           ]}
  schema "services" do
    field(:name, :string)
    field(:description, :string)
    # minutes
    field(:duration, :integer)

    belongs_to(:client, StarTickets.Accounts.Client)
    belongs_to(:form_template, StarTickets.Forms.FormTemplate)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(service, attrs) do
    service
    |> cast(attrs, [:name, :description, :duration, :client_id, :form_template_id])
    |> validate_required([:name, :duration, :client_id])
    |> validate_number(:duration, greater_than: 0, message: "deve ser maior que zero")
    |> foreign_key_constraint(:client_id)
  end
end
