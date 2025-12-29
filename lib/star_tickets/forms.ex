defmodule StarTickets.Forms do
  @moduledoc """
  The Forms context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  import StarTickets.QueryHelpers
  alias StarTickets.Repo

  alias StarTickets.Forms.FormTemplate
  alias StarTickets.Forms.FormField
  alias StarTickets.Accounts.Service

  ## Form Templates

  def list_templates(params \\ %{}) do
    client_id = params["client_id"]
    search_term = params["search"] || ""

    FormTemplate
    |> filter_by_client(client_id)
    |> search_templates(search_term)
    |> order_by(desc: :inserted_at)
    |> paginate(params)
    |> preload([:form_fields, :services])
    |> Repo.all()
  end

  def count_templates(search_term \\ "", client_id \\ nil) do
    FormTemplate
    |> filter_by_client(client_id)
    |> search_templates(search_term)
    |> Repo.aggregate(:count, :id)
  end

  def list_template_options(client_id) do
    FormTemplate
    |> filter_by_client(client_id)
    |> order_by(asc: :name)
    |> Repo.all()
  end

  defp filter_by_client(query, nil), do: query

  defp filter_by_client(query, client_id) do
    where(query, [t], t.client_id == ^client_id)
  end

  defp search_templates(query, ""), do: query

  defp search_templates(query, search_term) do
    where(
      query,
      [t],
      ilike(t.name, ^"%#{search_term}%") or ilike(t.description, ^"%#{search_term}%")
    )
  end

  def get_template!(id) do
    fields_query = from(f in FormField, order_by: [asc: f.position])

    sections_query =
      from(s in StarTickets.Forms.FormSection,
        order_by: [asc: s.position],
        preload: [form_fields: ^fields_query]
      )

    Repo.get!(FormTemplate, id)
    |> Repo.preload([:services, form_fields: fields_query, form_sections: sections_query])
  end

  def create_template(attrs \\ %{}) do
    %FormTemplate{}
    |> FormTemplate.changeset(attrs)
    |> put_services(attrs)
    |> Repo.insert()
  end

  def update_template(%FormTemplate{} = template, attrs) do
    template
    |> FormTemplate.changeset(attrs)
    |> put_services(attrs)
    |> Repo.update()
  end

  defp put_services(changeset, attrs) do
    if ids = attrs["service_ids"] do
      # Ensure ids are integers
      ids = Enum.map(ids, &String.to_integer(to_string(&1)))
      services = Repo.all(from(s in Service, where: s.id in ^ids))
      put_assoc(changeset, :services, services)
    else
      changeset
    end
  end

  def delete_template(%FormTemplate{} = template) do
    Repo.delete(template)
  end

  def change_template(%FormTemplate{} = template, attrs \\ %{}) do
    FormTemplate.changeset(template, attrs)
  end

  ## Form Fields

  def list_fields(template_id) do
    FormField
    |> where([f], f.form_template_id == ^template_id)
    |> order_by(asc: :position)
    |> Repo.all()
  end

  def get_field!(id), do: Repo.get!(FormField, id)

  def create_field(attrs \\ %{}) do
    %FormField{}
    |> FormField.changeset(attrs)
    |> Repo.insert()
  end

  def update_field(%FormField{} = field, attrs) do
    field
    |> FormField.changeset(attrs)
    |> Repo.update()
  end

  def delete_field(%FormField{} = field) do
    Repo.delete(field)
  end

  def change_field(%FormField{} = field, attrs \\ %{}) do
    FormField.changeset(field, attrs)
  end

  def move_field(%FormField{} = field, direction) when direction in ["up", "down"] do
    fields = list_fields(field.form_template_id)
    index = Enum.find_index(fields, &(&1.id == field.id))

    target_index = if direction == "up", do: index - 1, else: index + 1

    if target = Enum.at(fields, target_index) do
      Repo.transaction(fn ->
        Repo.update!(change_field(field, %{position: target.position}))
        Repo.update!(change_field(target, %{position: field.position}))
      end)
    else
      {:error, :no_move_possible}
    end
  end

  alias StarTickets.Forms.FormResponse

  def create_form_response(attrs \\ %{}) do
    %FormResponse{}
    |> FormResponse.changeset(attrs)
    |> Repo.insert()
  end
end
