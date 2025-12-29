defmodule StarTickets.Repo.Migrations.CreateTicketsTables do
  use Ecto.Migration

  def change do
    # Tickets table
    create table(:tickets) do
      add(:display_code, :string, null: false)
      add(:status, :string, default: "pending")
      add(:token, :uuid, null: false)
      add(:establishment_id, references(:establishments, on_delete: :delete_all), null: false)
      # Optional because ticket might be created by totem (no user) or reception (user)
      # But usually totem user creates it? Let's make it optional for now.
      add(:user_id, references(:users, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:tickets, [:token]))
    create(index(:tickets, [:establishment_id]))
    create(index(:tickets, [:status]))

    # Join table for many-to-many relationship between tickets and services
    create table(:tickets_services, primary_key: false) do
      add(:ticket_id, references(:tickets, on_delete: :delete_all), primary_key: true)
      add(:service_id, references(:services, on_delete: :delete_all), primary_key: true)
    end

    create(index(:tickets_services, [:ticket_id]))
    create(index(:tickets_services, [:service_id]))
  end
end
