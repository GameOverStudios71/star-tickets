defmodule StarTickets.Forms.FormTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "form_templates" do
    field(:name, :string)
    field(:description, :string)
    belongs_to(:client, StarTickets.Accounts.Client)
    has_many(:form_fields, StarTickets.Forms.FormField, on_delete: :delete_all)
    has_many(:services, StarTickets.Accounts.Service)

    timestamps()
  end

  @doc false
  def changeset(form_template, attrs) do
    form_template
    |> cast(attrs, [:name, :description, :client_id])
    |> validate_required([:name, :client_id])
  end
end
