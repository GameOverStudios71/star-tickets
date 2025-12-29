defmodule StarTickets.Reception do
  @moduledoc """
  The Reception context.
  """

  import Ecto.Query, warn: false
  alias StarTickets.Repo

  alias StarTickets.Reception.ReceptionDesk
  alias Phoenix.PubSub

  @topic "reception_desks"

  def subscribe do
    PubSub.subscribe(StarTickets.PubSub, @topic)
  end

  defp broadcast({:ok, desk}, event) do
    PubSub.broadcast(StarTickets.PubSub, @topic, {event, desk})
    {:ok, desk}
  end

  defp broadcast({:error, _} = error, _event), do: error

  def list_desks(establishment_id) do
    ReceptionDesk
    |> where([d], d.establishment_id == ^establishment_id)
    |> preload(:occupied_by_user)
    |> Repo.all()
  end

  def get_desk!(id), do: Repo.get!(ReceptionDesk, id)

  def create_desk(attrs \\ %{}) do
    %ReceptionDesk{}
    |> ReceptionDesk.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:desk_created)
  end

  def update_desk(%ReceptionDesk{} = desk, attrs) do
    desk
    |> ReceptionDesk.changeset(attrs)
    |> Repo.update()
    |> broadcast(:desk_updated)
  end

  def occupy_desk(%ReceptionDesk{} = desk, user_id) do
    # First, release any other desk occupied by this user
    release_desks_by_user(user_id)

    desk
    |> ReceptionDesk.occupation_changeset(%{occupied_by_user_id: user_id})
    |> Repo.update()
    |> broadcast(:desk_updated)
  end

  def release_desk(%ReceptionDesk{} = desk) do
    desk
    |> ReceptionDesk.occupation_changeset(%{occupied_by_user_id: nil})
    |> Repo.update()
    |> broadcast(:desk_updated)
  end

  def release_desks_by_user(user_id) do
    from(d in ReceptionDesk, where: d.occupied_by_user_id == ^user_id)
    |> Repo.update_all(set: [occupied_by_user_id: nil])

    # Since update_all doesn't return structs for broadcast, we might need to manually broadcast
    # or just let periodic fetch handle it, but for now we rely on the specific occupy call to broadcast the *new* state.
    # To be safer, we should probably fetch and broadcast, but let's keep it simple.
    # Actually, if we clear others, we should let clients know.
    # Use a query to find them first.
    desks_to_clear = Repo.all(from(d in ReceptionDesk, where: d.occupied_by_user_id == ^user_id))

    Enum.each(desks_to_clear, fn d ->
      broadcast({:ok, %{d | occupied_by_user_id: nil}}, :desk_updated)
    end)
  end
end
