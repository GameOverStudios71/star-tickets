defmodule StarTickets.Repo.Migrations.AddTvRoomsRelation do
  use Ecto.Migration

  def change do
    create table(:tv_rooms, primary_key: false) do
      add(:tv_id, references(:tvs, on_delete: :delete_all), null: false)
      add(:room_id, references(:rooms, on_delete: :delete_all), null: false)
    end

    create(unique_index(:tv_rooms, [:tv_id, :room_id]))

    # Add all_rooms flag to tvs table (similar to all_services)
    alter table(:tvs) do
      add(:all_rooms, :boolean, default: false)
    end
  end
end
