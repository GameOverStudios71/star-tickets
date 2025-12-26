defmodule StarTickets.Repo.Migrations.CreateRoomsAndRoomServices do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add(:name, :string, null: false)
      add(:capacity_threshold, :integer, default: 0)
      add(:establishment_id, references(:establishments, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:rooms, [:establishment_id]))

    create table(:room_services, primary_key: false) do
      add(:room_id, references(:rooms, on_delete: :delete_all), null: false)
      add(:service_id, references(:services, on_delete: :delete_all), null: false)
    end

    create(index(:room_services, [:room_id]))
    create(index(:room_services, [:service_id]))
    create(unique_index(:room_services, [:room_id, :service_id]))
  end
end
