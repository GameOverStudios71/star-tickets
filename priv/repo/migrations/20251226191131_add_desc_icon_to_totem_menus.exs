defmodule StarTickets.Repo.Migrations.AddDescIconToTotemMenus do
  use Ecto.Migration

  def change do
    alter table(:totem_menus) do
      add(:description, :text)
      add(:icon_class, :string)
    end
  end
end
