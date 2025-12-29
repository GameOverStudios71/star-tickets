defmodule StarTickets.Repo.Migrations.AddOccupiedByToReceptionDesks do
  use Ecto.Migration

  def change do
    alter table(:reception_desks) do
      add(:occupied_by_user_id, references(:users, on_delete: :nilify_all))
    end

    create(index(:reception_desks, [:occupied_by_user_id]))
  end
end
