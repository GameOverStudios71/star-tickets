defmodule StarTickets.Repo.Migrations.CreateServicesTable do
  use Ecto.Migration

  def change do
    create table(:services) do
      add(:name, :string, null: false)
      # in minutes
      add(:duration, :integer, null: false)
      add(:client_id, references(:clients, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:services, [:client_id]))
  end
end
