defmodule StarTickets.Repo.Migrations.AddAllServicesToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add(:all_services, :boolean, default: false)
    end
  end
end
