defmodule StarTickets.Repo.Migrations.FixTicketIsPriorityType do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE tickets ALTER COLUMN is_priority DROP DEFAULT")

    execute(
      "ALTER TABLE tickets ALTER COLUMN is_priority TYPE boolean USING (CASE WHEN is_priority = 1 THEN TRUE ELSE FALSE END)"
    )

    execute("ALTER TABLE tickets ALTER COLUMN is_priority SET DEFAULT false")
  end

  def down do
    execute("ALTER TABLE tickets ALTER COLUMN is_priority DROP DEFAULT")

    execute(
      "ALTER TABLE tickets ALTER COLUMN is_priority TYPE integer USING (CASE WHEN is_priority THEN 1 ELSE 0 END)"
    )

    execute("ALTER TABLE tickets ALTER COLUMN is_priority SET DEFAULT 0")
  end
end
