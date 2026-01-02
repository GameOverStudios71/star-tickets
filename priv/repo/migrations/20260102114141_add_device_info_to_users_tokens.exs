defmodule StarTickets.Repo.Migrations.AddDeviceInfoToUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      # "Chrome on Windows"
      add :device_name, :string
      # "desktop", "mobile", "tablet"
      add :device_type, :string
      # "Chrome 120"
      add :browser, :string
      # "Windows 11"
      add :os, :string
      # "189.xxx.xxx.xxx"
      add :ip_address, :string
      # "São Paulo, BR" (optional)
      add :location, :string
      # Last activity timestamp
      add :last_used_at, :utc_datetime
    end

    # Index for faster device queries per user
    create index(:users_tokens, [:user_id, :context])
  end
end
