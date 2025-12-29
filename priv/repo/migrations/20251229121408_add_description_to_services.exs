defmodule StarTickets.Repo.Migrations.AddDescriptionToServices do
  use Ecto.Migration

  def change do
    alter table(:services) do
      add(:description, :text)
    end
  end
end
