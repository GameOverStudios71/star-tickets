defmodule StarTickets.Repo.Migrations.CreateTvsAndTvServices do
  use Ecto.Migration

  def change do
    create table(:tvs) do
      add(:name, :string, null: false)
      add(:news_enabled, :boolean, default: false, null: false)
      add(:news_url, :string)
      add(:establishment_id, references(:establishments, on_delete: :delete_all), null: false)
      add(:user_id, references(:users, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:tvs, [:establishment_id]))
    create(unique_index(:tvs, [:user_id]))

    create table(:tv_services) do
      add(:tv_id, references(:tvs, on_delete: :delete_all), null: false)
      add(:service_id, references(:services, on_delete: :delete_all), null: false)
    end

    create(index(:tv_services, [:tv_id]))
    create(index(:tv_services, [:service_id]))
    create(unique_index(:tv_services, [:tv_id, :service_id]))
  end
end
