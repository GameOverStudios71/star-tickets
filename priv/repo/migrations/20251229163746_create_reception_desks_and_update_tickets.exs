defmodule StarTickets.Repo.Migrations.CreateReceptionDesksAndUpdateTickets do
  use Ecto.Migration

  def change do
    create table(:reception_desks) do
      add(:name, :string, null: false)
      add(:is_active, :boolean, default: true, null: false)
      add(:establishment_id, references(:establishments, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:reception_desks, [:establishment_id]))

    alter table(:tickets) do
      add(:reception_desk_id, references(:reception_desks, on_delete: :nilify_all))

      # Using integer 0/1 to match legacy if preferred, or boolean. Legacy init.js says INTEGER DEFAULT 0. Let's use boolean for Elixir but map it? No, stick to Ecto primitives. Boolean is fine, but legacy used 0/1. I'll use boolean.
      add(:is_priority, :integer, default: 0)
      add(:health_insurance_name, :string)
      add(:webcheckin_status, :string)
      add(:webcheckin_token, :string)
      add(:webcheckin_started_at, :utc_datetime)
      add(:webcheckin_completed_at, :utc_datetime)
      add(:webcheckin_token_expires_at, :utc_datetime)
    end

    create(index(:tickets, [:reception_desk_id]))
    create(index(:tickets, [:webcheckin_token]))
  end
end
