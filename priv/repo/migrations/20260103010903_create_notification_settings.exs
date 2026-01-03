defmodule StarTickets.Repo.Migrations.CreateNotificationSettings do
  use Ecto.Migration

  def change do
    create table(:notification_settings) do
      add :notification_type, :string, null: false
      add :role, :string, null: false
      add :whatsapp_enabled, :boolean, default: true, null: false
      add :inbox_enabled, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:notification_settings, [:notification_type, :role])
  end
end
