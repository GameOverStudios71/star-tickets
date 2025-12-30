# Script to link ALL services of an establishment to ALL its rooms
# Usage: mix run priv/repo/link_room_services.exs

alias StarTickets.Repo
alias StarTickets.Accounts.{Room, Service, Establishment}
import Ecto.Query

IO.puts("🔗 Linking Services to Rooms...")

# Get all establishments
establishments = Repo.all(Establishment)

Enum.each(establishments, fn est ->
  IO.puts("\n🏢 Processing #{est.name}...")

  # Get all services for this establishment
  # Note: Services are linked to Client, but usually shared or filtered by menu.
  # For now, let's link ALL services of the client to the rooms.
  services = Repo.all(from(s in Service, where: s.client_id == ^est.client_id))

  IO.puts("   Found #{length(services)} services available.")

  # Get all rooms
  rooms =
    Repo.all(from(r in Room, where: r.establishment_id == ^est.id)) |> Repo.preload(:services)

  Enum.each(rooms, fn room ->
    # Create changeset to put assoc
    # We use a schemaless changeset or just Room changeset if it handles association

    # We need to use put_assoc.
    changeset =
      room
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:services, services)

    case Repo.update(changeset) do
      {:ok, _} -> IO.puts("   ✅ Linked all services to #{room.name}")
      {:error, _} -> IO.puts("   ❌ Failed to link services to #{room.name}")
    end
  end)
end)

IO.puts("\n✨ Done! Rooms are now capable of performing services.")
