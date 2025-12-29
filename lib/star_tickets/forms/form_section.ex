defmodule StarTickets.Forms.FormSection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "form_sections" do
    field(:title, :string)
    field(:position, :integer, default: 0)
    belongs_to(:form_template, StarTickets.Forms.FormTemplate)
    has_many(:form_fields, StarTickets.Forms.FormField)

    timestamps()
  end

  def changeset(form_section, attrs) do
    form_section
    |> cast(attrs, [:title, :position, :form_template_id])
    |> validate_required([:title, :form_template_id])
  end
end
