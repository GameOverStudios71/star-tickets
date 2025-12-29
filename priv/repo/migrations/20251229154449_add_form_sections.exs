defmodule StarTickets.Repo.Migrations.AddFormSections do
  use Ecto.Migration

  def change do
    create table(:form_sections) do
      add(:title, :string, null: false)
      add(:position, :integer, default: 0)
      add(:form_template_id, references(:form_templates, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:form_sections, [:form_template_id]))

    alter table(:form_fields) do
      add(:form_section_id, references(:form_sections, on_delete: :delete_all))
    end

    create(index(:form_fields, [:form_section_id]))
  end
end
