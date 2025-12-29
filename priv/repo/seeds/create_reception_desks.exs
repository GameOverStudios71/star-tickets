# Script to populate Reception Desks
# Run with: mix run priv/repo/seeds/create_reception_desks.exs

alias StarTickets.Repo
alias StarTickets.Accounts.Establishment
alias StarTickets.Reception.ReceptionDesk
import Ecto.Query

# Ensure required aliases are loaded
# (In mix run context they should be loaded if app is started, but explicit doesn't hurt)

IO.puts("🔄 Seeding Reception Desks...")

establishments = Repo.all(Establishment)

if Enum.empty?(establishments) do
  IO.puts("⚠️ No establishments found! Run the main seeds first.")
else
  for est <- establishments do
    IO.puts("  📍 Processing #{est.name} (#{est.code})...")

    for i <- 1..4 do
      desk_name = "Mesa #{i}"

      existing =
        Repo.one(
          from(d in ReceptionDesk, where: d.establishment_id == ^est.id and d.name == ^desk_name)
        )

      if existing do
        IO.puts("    ✓ #{desk_name} exists")
      else
        %ReceptionDesk{}
        |> ReceptionDesk.changeset(%{
          name: desk_name,
          establishment_id: est.id,
          is_active: true
        })
        |> Repo.insert!()

        IO.puts("    + #{desk_name} created")
      end
    end
  end
end

IO.puts("✅ Reception Desks seeding completed.")
