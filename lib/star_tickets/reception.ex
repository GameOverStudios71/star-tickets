defmodule StarTickets.Reception do
  @moduledoc """
  The Reception context.
  Now uses Room entity with type="reception" instead of separate ReceptionDesk.
  """

  import Ecto.Query, warn: false
  alias StarTickets.Repo
  alias StarTickets.Accounts.Room
  alias Phoenix.PubSub

  @topic "reception_rooms"

  def subscribe do
    PubSub.subscribe(StarTickets.PubSub, @topic)
  end

  defp broadcast({:ok, room}, event) do
    PubSub.broadcast(StarTickets.PubSub, @topic, {event, room})
    {:ok, room}
  end

  defp broadcast({:error, _} = error, _event), do: error

  @doc """
  Lists rooms that can be used by reception (type = reception or both).
  """
  def list_reception_rooms(establishment_id) do
    Room
    |> where([r], r.establishment_id == ^establishment_id)
    |> where([r], r.type in ["reception", "both"])
    |> where([r], r.is_active == true)
    |> preload(:occupied_by_user)
    |> Repo.all()
  end

  def get_room!(id), do: Repo.get!(Room, id) |> Repo.preload(:occupied_by_user)

  def occupy_room(%Room{} = room, user_id) do
    # First, release any other room occupied by this user
    release_rooms_by_user(user_id)

    room
    |> Room.occupation_changeset(%{occupied_by_user_id: user_id})
    |> Repo.update()
    |> broadcast(:room_updated)
  end

  def release_room(%Room{} = room) do
    room
    |> Room.occupation_changeset(%{occupied_by_user_id: nil})
    |> Repo.update()
    |> broadcast(:room_updated)
  end

  def release_rooms_by_user(user_id) do
    # Find rooms to clear first (for broadcast)
    rooms_to_clear = Repo.all(from(r in Room, where: r.occupied_by_user_id == ^user_id))

    # Clear all at once
    from(r in Room, where: r.occupied_by_user_id == ^user_id)
    |> Repo.update_all(set: [occupied_by_user_id: nil])

    # Broadcast updates
    Enum.each(rooms_to_clear, fn r ->
      broadcast({:ok, %{r | occupied_by_user_id: nil}}, :room_updated)
    end)
  end
end
