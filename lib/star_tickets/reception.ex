defmodule StarTickets.Reception do
  @moduledoc """
  The Reception context.
  """

  import Ecto.Query, warn: false
  alias StarTickets.Repo

  alias StarTickets.Reception.ReceptionDesk

  def list_desks(establishment_id) do
    ReceptionDesk
    |> where([d], d.establishment_id == ^establishment_id)
    |> Repo.all()
  end

  def get_desk!(id), do: Repo.get!(ReceptionDesk, id)

  def create_desk(attrs \\ %{}) do
    %ReceptionDesk{}
    |> ReceptionDesk.changeset(attrs)
    |> Repo.insert()
  end

  def update_desk(%ReceptionDesk{} = desk, attrs) do
    desk
    |> ReceptionDesk.changeset(attrs)
    |> Repo.update()
  end
end
