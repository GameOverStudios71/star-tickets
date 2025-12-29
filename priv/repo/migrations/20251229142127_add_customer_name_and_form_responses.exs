defmodule StarTickets.Repo.Migrations.AddCustomerNameAndFormResponses do
  use Ecto.Migration

  def change do
    alter table(:tickets) do
      add(:customer_name, :string)
    end

    create table(:form_responses) do
      add(:value, :text)
      add(:ticket_id, references(:tickets, on_delete: :delete_all))
      add(:form_field_id, references(:form_fields, on_delete: :delete_all))

      timestamps(type: :utc_datetime)
    end

    create(index(:form_responses, [:ticket_id]))
    create(index(:form_responses, [:form_field_id]))
  end
end
