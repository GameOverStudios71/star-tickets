defmodule StarTickets.Repo.Migrations.AddRoomIdToTickets do
  use Ecto.Migration

  def change do
    alter table(:tickets) do
      add(:room_id, references(:rooms, on_delete: :nilify_all))
    end

    create(index(:tickets, [:room_id]))
  end
end
