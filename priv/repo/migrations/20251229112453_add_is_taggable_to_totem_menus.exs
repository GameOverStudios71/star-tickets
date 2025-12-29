defmodule StarTickets.Repo.Migrations.AddIsTaggableToTotemMenus do
  use Ecto.Migration

  def change do
    alter table(:totem_menus) do
      add(:is_taggable, :boolean, default: false)
    end
  end
end
