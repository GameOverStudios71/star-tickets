defmodule StarTickets.Repo.Migrations.AddAllServicesToTvs do
  use Ecto.Migration

  def change do
    alter table(:tvs) do
      add(:all_services, :boolean, default: false, null: false)
    end
  end
end
