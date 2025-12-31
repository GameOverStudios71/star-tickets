defmodule StarTickets.Repo.Migrations.ConsolidateRoomsAndDesks do
  use Ecto.Migration

  def up do
    # Phase 1: Add new columns to rooms table
    alter table(:rooms) do
      add(:type, :string, default: "professional")
      add(:is_active, :boolean, default: true)
    end

    # Phase 2: Migrate data from reception_desks to rooms
    # Insert all reception_desks as rooms with type="reception"
    execute("""
    INSERT INTO rooms (name, is_active, type, establishment_id, occupied_by_user_id, inserted_at, updated_at)
    SELECT name, is_active, 'reception', establishment_id, occupied_by_user_id, inserted_at, updated_at
    FROM reception_desks
    """)

    # Phase 3: Update tickets to point to migrated rooms
    # First, we need to map old desk_id to new room_id
    # Since we just inserted desks as rooms, we need to match by name + establishment
    execute("""
    UPDATE tickets t
    SET room_id = (
      SELECT r.id FROM rooms r
      WHERE r.name = (SELECT rd.name FROM reception_desks rd WHERE rd.id = t.reception_desk_id)
      AND r.establishment_id = t.establishment_id
      AND r.type = 'reception'
      LIMIT 1
    )
    WHERE t.reception_desk_id IS NOT NULL
    """)

    # Phase 4: Remove the reception_desk_id column from tickets
    alter table(:tickets) do
      remove(:reception_desk_id)
    end

    # Phase 5: Drop the reception_desks table
    drop(table(:reception_desks))
  end

  def down do
    # Recreate reception_desks table
    create table(:reception_desks) do
      add(:name, :string, null: false)
      add(:is_active, :boolean, default: true)
      add(:establishment_id, references(:establishments, on_delete: :delete_all), null: false)
      add(:occupied_by_user_id, references(:users, on_delete: :nilify_all))
      timestamps(type: :utc_datetime)
    end

    # Re-add reception_desk_id to tickets
    alter table(:tickets) do
      add(:reception_desk_id, references(:reception_desks, on_delete: :nilify_all))
    end

    # Remove added columns from rooms
    alter table(:rooms) do
      remove(:type)
      remove(:is_active)
    end
  end
end
