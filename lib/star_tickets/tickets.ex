defmodule StarTickets.Tickets do
  @moduledoc """
  The Tickets context.
  """

  import Ecto.Query, warn: false
  alias StarTickets.Repo
  alias StarTickets.Tickets.Ticket
  alias StarTickets.Accounts.Service
  alias Phoenix.PubSub

  @topic "tickets"

  def subscribe do
    PubSub.subscribe(StarTickets.PubSub, @topic)
  end

  defp broadcast({:ok, ticket}, event) do
    PubSub.broadcast(StarTickets.PubSub, @topic, {event, ticket})
    {:ok, ticket}
  end

  defp broadcast({:error, _} = error, _event), do: error

  @doc """
  Creates a ticket.

  ## Examples

      iex> create_ticket(%{field: value})
      {:ok, %Ticket{}}

      iex> create_ticket(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ticket(%Ticket{} = ticket, attrs) do
    ticket
    |> Ticket.changeset(attrs)
    |> Repo.update()
    |> broadcast(:ticket_updated)
  end

  @doc """
  Updates a ticket with new attributes and replaces its services.
  """
  def update_ticket_with_services(%Ticket{} = ticket, attrs, services) do
    ticket
    |> Ticket.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:services, services)
    |> Repo.update()
    |> broadcast(:ticket_updated)
  end

  def create_ticket(attrs \\ %{}) do
    services = attrs[:services] || []
    tags = attrs[:tags] || []

    # Generate UUID token if not provided
    token = Ecto.UUID.generate()
    attrs = Map.put_new(attrs, :token, token)

    %Ticket{}
    |> Ticket.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:services, services)
    |> Ecto.Changeset.put_assoc(:tags, tags)
    |> Repo.insert()
    |> broadcast(:ticket_created)
  end

  def list_reception_tickets(establishment_id) do
    today = Date.utc_today() |> DateTime.new!(~T[00:00:00])

    Ticket
    |> where([t], t.establishment_id == ^establishment_id)
    |> where([t], t.inserted_at >= ^today)
    |> preload([:services, :reception_desk, :tags])
    |> order_by([t], desc: t.is_priority, asc: t.inserted_at)
    |> Repo.all()
  end

  def assign_ticket_to_desk(%Ticket{} = ticket, desk_id) do
    update_ticket(ticket, %{reception_desk_id: desk_id})
  end

  def update_ticket_status(%Ticket{} = ticket, status) do
    attrs = %{status: status}

    # If returning to waiting, maybe clear user assignment?
    # For now, let's keep it simple. If status is "WAITING_RECEPTION", clear user.
    attrs =
      if status == "WAITING_RECEPTION" do
        Map.put(attrs, :user_id, nil)
      else
        attrs
      end

    update_ticket(ticket, attrs)
  end

  def start_attendance(%Ticket{} = ticket, user_id) do
    update_ticket(ticket, %{
      status: "IN_RECEPTION",
      user_id: user_id
    })
  end

  def count_waiting_tickets(establishment_id) do
    today = Date.utc_today() |> DateTime.new!(~T[00:00:00])

    Ticket
    |> where([t], t.establishment_id == ^establishment_id)
    |> where([t], t.inserted_at >= ^today)
    |> where([t], t.status == "WAITING_RECEPTION")
    |> Repo.aggregate(:count, :id)
  end

  def load_full_data(%Ticket{} = ticket) do
    Repo.preload(ticket, [
      :services,
      :establishment,
      form_responses: [:form_field]
      # :webcheckin_files
    ])
  end

  @doc """
  Gets a single ticket by token.

  Raises `Ecto.NoResultsError` if the Ticket does not exist.

  ## Examples

      iex> get_ticket_by_token!("123")
      %Ticket{}

      iex> get_ticket_by_token!("456")
      ** (Ecto.NoResultsError)

  """
  def get_ticket_by_token!(token) do
    Repo.get_by!(Ticket, token: token) |> Repo.preload([:services, :establishment])
  end

  @doc """
  Gets a single ticket.

  Raises `Ecto.NoResultsError` if the Ticket does not exist.
  """
  def get_ticket!(id),
    do: Repo.get!(Ticket, id) |> Repo.preload([:services, :establishment, :tags])

  @doc """
  List tickets waiting for professional attention (first time or returning).
  Ideally filters by tickets that possess services the `room_id` can perform.
  """
  def list_professional_tickets(establishment_id, room_services) do
    today = Date.utc_today() |> DateTime.new!(~T[00:00:00])
    room_service_ids = Enum.map(room_services, & &1.id)

    Ticket
    |> where([t], t.establishment_id == ^establishment_id)
    |> where([t], t.inserted_at >= ^today)
    |> where([t], t.status in ["WAITING_PROFESSIONAL", "WAITING_NEXT_SERVICE"])
    |> preload([:services, :reception_desk, :tags, :room, :user])
    |> order_by([t], desc: t.is_priority, asc: t.inserted_at)
    |> Repo.all()
    |> Enum.filter(fn ticket ->
      # Only show if ticket needs a service this room provides
      Enum.any?(ticket.services, fn s -> s.id in room_service_ids end)
    end)
  end

  def call_ticket_to_room(%Ticket{} = ticket, user_id, room_id) do
    update_ticket(ticket, %{
      status: "CALLED_PROFESSIONAL",
      user_id: user_id,
      room_id: room_id
    })
  end

  def start_professional_attendance(%Ticket{} = ticket) do
    update_ticket(ticket, %{status: "IN_ATTENDANCE"})
  end

  @doc """
  Finishes attendance. Debits (removes) services performed by this room.
  If services remain, returns to queue. Else finishes.
  """
  def finish_attendance_and_route(%Ticket{} = ticket, room_services) do
    ticket = Repo.preload(ticket, :services, force: true)

    # identify performed services (intersection)
    room_service_ids = Enum.map(room_services, & &1.id)
    executed_services = Enum.filter(ticket.services, fn s -> s.id in room_service_ids end)

    # Debit services (remove from association)
    # We use put_assoc with the remaining list (subtraction)
    remaining_services = Enum.reject(ticket.services, fn s -> s.id in room_service_ids end)

    # We need to use specific Changeset to remove the association explicitly, or just set the new list
    changeset =
      ticket
      |> Ticket.changeset(%{})
      |> Ecto.Changeset.put_assoc(:services, remaining_services)

    Repo.update!(changeset)

    # Decide next status
    if Enum.empty?(remaining_services) do
      # All done
      update_ticket(ticket, %{status: "FINISHED"})
    else
      # Back to queue
      update_ticket(ticket, %{
        status: "WAITING_NEXT_SERVICE",
        user_id: nil,
        room_id: nil
      })
    end
  end

  @doc """
  Checks if any of the ticket services has a form template.
  """
  def ticket_has_forms?(ticket) do
    # Preload services if not loaded
    ticket = Repo.preload(ticket, services: :form_template)

    Enum.any?(ticket.services, fn service ->
      service.form_template_id != nil
    end)
  end
end
