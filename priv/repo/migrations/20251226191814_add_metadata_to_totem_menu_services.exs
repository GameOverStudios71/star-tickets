defmodule StarTickets.Repo.Migrations.AddMetadataToTotemMenuServices do
  use Ecto.Migration

  def change do
    alter table(:totem_menu_services) do
      add(:description, :text)
      add(:icon_class, :string)
    end
  end
end
