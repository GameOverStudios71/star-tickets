defmodule StarTickets.Repo.Migrations.CreateFormsManagement do
  use Ecto.Migration

  def change do
    create table(:form_templates) do
      add(:name, :string, null: false)
      add(:description, :text)
      add(:client_id, references(:clients, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:form_templates, [:client_id]))

    create table(:form_fields) do
      add(:form_template_id, references(:form_templates, on_delete: :delete_all), null: false)
      add(:label, :string, null: false)
      add(:type, :string, null: false)
      # JSONB for select/radio options
      add(:options, :map)
      add(:required, :boolean, default: false, null: false)
      add(:position, :integer, default: 0, null: false)

      timestamps()
    end

    create(index(:form_fields, [:form_template_id]))

    alter table(:services) do
      add(:form_template_id, references(:form_templates, on_delete: :nilify_all))
    end

    create(index(:services, [:form_template_id]))
  end
end
