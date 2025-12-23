defmodule StarTickets.Repo.Migrations.CreateEstablishments do
  use Ecto.Migration

  def change do
    create table(:establishments) do
      add :name, :string
      add :code, :string
      add :address, :string
      add :phone, :string
      add :is_active, :boolean, default: false, null: false
      add :client_id, references(:clients, on_delete: :nothing)
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:establishments, [:user_id])

    create index(:establishments, [:client_id])
  end
end
