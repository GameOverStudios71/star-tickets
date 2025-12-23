defmodule StarTickets.Repo.Migrations.AddMultiTenantFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:name, :string)
      add(:username, :string)
      add(:role, :string, default: "professional")
      add(:client_id, references(:clients, on_delete: :nilify_all))
      add(:establishment_id, references(:establishments, on_delete: :nilify_all))
    end

    create(unique_index(:users, [:username]))
    create(index(:users, [:client_id]))
    create(index(:users, [:establishment_id]))
  end
end
