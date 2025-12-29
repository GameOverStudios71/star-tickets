defmodule StarTickets.Repo.Migrations.CreateTicketsTags do
  use Ecto.Migration

  def change do
    create table(:tickets_tags, primary_key: false) do
      add(:ticket_id, references(:tickets, on_delete: :delete_all), null: false)
      add(:totem_menu_id, references(:totem_menus, on_delete: :delete_all), null: false)
    end

    create(index(:tickets_tags, [:ticket_id]))
    create(index(:tickets_tags, [:totem_menu_id]))
    create(unique_index(:tickets_tags, [:ticket_id, :totem_menu_id]))
  end
end
