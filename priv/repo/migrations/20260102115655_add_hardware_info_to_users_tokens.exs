defmodule StarTickets.Repo.Migrations.AddHardwareInfoToUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      # navigator.hardwareConcurrency
      add :cpu_cores, :integer
      # navigator.deviceMemory
      add :memory_gb, :float
      # "1920x1080"
      add :screen_resolution, :string
      # navigator.platform
      add :platform, :string
      # navigator.language
      add :language, :string
      # navigator.connection.effectiveType
      add :connection_type, :string
      # Intl.DateTimeFormat timezone
      add :timezone, :string
    end
  end
end
