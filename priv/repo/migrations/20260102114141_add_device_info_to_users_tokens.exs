defmodule StarTickets.Repo.Migrations.AddDeviceInfoToUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add :device_name, :string        # "Chrome on Windows"
      add :device_type, :string        # "desktop", "mobile", "tablet"
      add :browser, :string            # "Chrome 120"
      add :os, :string                 # "Windows 11"
      add :ip_address, :string         # "189.xxx.xxx.xxx"
      add :location, :string           # "São Paulo, BR" (optional)
      add :last_used_at, :utc_datetime # Last activity timestamp
    end

    # Index for faster device queries per user
    create index(:users_tokens, [:user_id, :context])
  end
end
