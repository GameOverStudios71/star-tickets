defmodule StarTickets.Forms.FormField do
  use Ecto.Schema
  import Ecto.Changeset

  schema "form_fields" do
    field(:label, :string)
    field(:type, :string)
    field(:placeholder, :string)
    field(:options, :map, default: %{})
    field(:required, :boolean, default: false)
    field(:position, :integer, default: 0)

    belongs_to(:form_template, StarTickets.Forms.FormTemplate)
    belongs_to(:form_section, StarTickets.Forms.FormSection)
    has_many(:form_responses, StarTickets.Forms.FormResponse)

    timestamps()
  end

  @doc false
  def changeset(form_field, attrs) do
    form_field
    |> cast(attrs, [
      :label,
      :type,
      :placeholder,
      :options,
      :required,
      :position,
      :position,
      :form_template_id,
      :form_section_id
    ])
    |> validate_required([:label, :type, :form_template_id])
    |> validate_inclusion(:type, [
      "text",
      "textarea",
      "number",
      "checkbox",
      "radio",
      "select",
      "file"
    ])
  end
end
