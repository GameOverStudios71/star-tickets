defmodule StarTickets.Repo.Migrations.CreateTotemMenus do
  use Ecto.Migration

  def change do
    create table(:totem_menus) do
      add(:name, :string, null: false)
      # tag, category
      add(:type, :string, null: false)
      add(:position, :integer, default: 0)
      add(:establishment_id, references(:establishments, on_delete: :delete_all), null: false)
      add(:parent_id, references(:totem_menus, on_delete: :delete_all))

      timestamps()
    end

    create(index(:totem_menus, [:establishment_id]))
    create(index(:totem_menus, [:parent_id]))

    create table(:totem_menu_services) do
      add(:totem_menu_id, references(:totem_menus, on_delete: :delete_all), null: false)
      add(:service_id, references(:services, on_delete: :delete_all), null: false)
      add(:position, :integer, default: 0)
    end

    create(index(:totem_menu_services, [:totem_menu_id]))
    create(index(:totem_menu_services, [:service_id]))
    create(unique_index(:totem_menu_services, [:totem_menu_id, :service_id]))
  end
end
