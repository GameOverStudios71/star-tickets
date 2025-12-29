defmodule StarTickets.Repo.Migrations.RemoveTypeFromTotemMenus do
  use Ecto.Migration

  def change do
    alter table(:totem_menus) do
      remove(:type)
    end
  end
end
