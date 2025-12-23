defmodule StarTickets.Repo.Migrations.AddUniqueConstraintsToEstablishments do
  use Ecto.Migration

  def change do
    # Enforce unique name per client
    create(unique_index(:establishments, [:client_id, :name]))

    # Enforce unique code per client
    create(unique_index(:establishments, [:client_id, :code]))
  end
end
