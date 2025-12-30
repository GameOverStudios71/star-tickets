defmodule StarTickets.Repo.Migrations.AddOccupationToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add(:occupied_by_user_id, references(:users, on_delete: :nilify_all))
    end

    create(index(:rooms, [:occupied_by_user_id]))
  end
end
