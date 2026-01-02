defmodule StarTickets.Tickets do
  @moduledoc """
  The Tickets context.
  """

  import Ecto.Query, warn: false
  alias StarTickets.Repo
  alias StarTickets.Tickets.Ticket
  alias Phoenix.PubSub

  @topic "tickets"

  def subscribe do
    PubSub.subscribe(StarTickets.PubSub, @topic)
  end

  defp broadcast({:ok, ticket}, event) do
    PubSub.broadcast(StarTickets.PubSub, @topic, {event, ticket})
    {:ok, ticket}
  end

  # defp broadcast({:error, _} = error, _event), do: error

  alias StarTickets.Audit

  @doc """
  Updates a ticket with new attributes.
  """
  def update_ticket(%Ticket{} = ticket, attrs, actor \\ nil) do
    changeset = Ticket.changeset(ticket, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:ticket, changeset)
    |> Ecto.Multi.run(:log, fn repo, %{ticket: updated_ticket} ->
      Audit.log_diff(repo, ticket, updated_ticket, "TICKET", actor)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{ticket: ticket}} -> broadcast({:ok, ticket}, :ticket_updated)
      {:error, _, reason, _} -> {:error, reason}
    end
  end

  @doc """
  Updates a ticket with new attributes and replaces its services.
  """
  def update_ticket_with_services(%Ticket{} = ticket, attrs, services, actor \\ nil) do
    changeset =
      ticket
      |> Ticket.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:services, services)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:ticket, changeset)
    |> Ecto.Multi.run(:log, fn repo, %{ticket: updated_ticket} ->
      Audit.log_diff(repo, ticket, updated_ticket, "TICKET_SERVICES", actor)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{ticket: ticket}} -> broadcast({:ok, ticket}, :ticket_updated)
      {:error, _, reason, _} -> {:error, reason}
    end
  end

  def create_ticket(attrs \\ %{}, actor \\ nil) do
    services = attrs[:services] || []
    tags = attrs[:tags] || []

    # Generate UUID token if not provided
    token = Ecto.UUID.generate()
    attrs = Map.put_new(attrs, :token, token)

    changeset =
      %Ticket{}
      |> Ticket.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:services, services)
      |> Ecto.Changeset.put_assoc(:tags, tags)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:ticket, changeset)
    |> Ecto.Multi.run(:log, fn _repo, %{ticket: ticket} ->
      # Check if any service has a form template
      has_forms = Enum.any?(services, fn s -> s.form_template_id != nil end)

      Audit.log_action(
        "TICKET_CREATED",
        %{
          resource_type: "Ticket",
          resource_id: to_string(ticket.id),
          details: %{code: ticket.display_code, has_forms: has_forms}
        },
        actor
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{ticket: ticket}} -> broadcast({:ok, ticket}, :ticket_created)
      {:error, _, reason, _} -> {:error, reason}
    end
  end

  def list_reception_tickets(establishment_id) do
    today = Date.utc_today() |> DateTime.new!(~T[00:00:00])

    Ticket
    |> where([t], t.establishment_id == ^establishment_id)
    |> where([t], t.inserted_at >= ^today)
    |> preload([:services, :room, :tags])
    |> order_by([t], desc: t.is_priority, asc: t.inserted_at)
    |> Repo.all()
  end

  def assign_ticket_to_room(%Ticket{} = ticket, room_id, actor \\ nil) do
    update_ticket(ticket, %{room_id: room_id}, actor)
  end

  def update_ticket_status(%Ticket{} = ticket, status, actor \\ nil) do
    attrs = %{status: status}

    # If returning to waiting, maybe clear user assignment?
    # For now, let's keep it simple. If status is "WAITING_RECEPTION", clear user.
    attrs =
      if status == "WAITING_RECEPTION" do
        Map.put(attrs, :user_id, nil)
      else
        attrs
      end

    update_ticket(ticket, attrs, actor)
  end

  @doc """
  Lists tickets that are currently called (for TV rotation).
  Includes both reception and professional calls.
  """
  def list_called_tickets(establishment_id) do
    today = Date.utc_today() |> DateTime.new!(~T[00:00:00])

    Ticket
    |> where([t], t.establishment_id == ^establishment_id)
    |> where([t], t.inserted_at >= ^today)
    |> where([t], t.status in ["CALLED_RECEPTION", "CALLED_PROFESSIONAL"])
    |> preload([:room, :services])
    |> order_by([t], asc: t.updated_at)
    |> Repo.all()
  end

  def start_attendance(%Ticket{} = ticket, user_id, actor \\ nil) do
    update_ticket(
      ticket,
      %{
        status: "IN_RECEPTION",
        user_id: user_id
      },
      actor
    )
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
    |> preload([:services, :tags, :room, :user])
    |> order_by([t], desc: t.is_priority, asc: t.inserted_at)
    |> Repo.all()
    |> Enum.filter(fn ticket ->
      # Only show if ticket needs a service this room provides
      Enum.any?(ticket.services, fn s -> s.id in room_service_ids end)
    end)
  end

  @doc """
  List tickets finished by a specific professional today.
  """
  def list_finished_professional_tickets(establishment_id, user_id) do
    today = Date.utc_today() |> DateTime.new!(~T[00:00:00])

    Ticket
    |> where([t], t.establishment_id == ^establishment_id)
    |> where([t], t.inserted_at >= ^today)
    |> where([t], t.status == "FINISHED")
    |> where([t], t.user_id == ^user_id)
    |> preload([:services, :room, :user])
    |> order_by([t], desc: t.updated_at)
    |> Repo.all()
  end

  def call_ticket_to_room(%Ticket{} = ticket, user_id, room_id, actor \\ nil) do
    result =
      update_ticket(
        ticket,
        %{
          status: "CALLED_PROFESSIONAL",
          user_id: user_id,
          room_id: room_id
        },
        actor
      )

    # Broadcast for TV display
    case result do
      {:ok, updated_ticket} ->
        updated_ticket = Repo.preload(updated_ticket, [:room, :services])
        PubSub.broadcast(StarTickets.PubSub, @topic, {:ticket_called, updated_ticket})
        {:ok, updated_ticket}

      error ->
        error
    end
  end

  def call_ticket_reception(%Ticket{} = ticket, user_id, room_id, actor \\ nil) do
    result =
      update_ticket(
        ticket,
        %{
          status: "CALLED_RECEPTION",
          user_id: user_id,
          room_id: room_id
        },
        actor
      )

    # Broadcast for TV display
    case result do
      {:ok, updated_ticket} ->
        updated_ticket = Repo.preload(updated_ticket, [:room, :services])
        PubSub.broadcast(StarTickets.PubSub, @topic, {:ticket_called, updated_ticket})
        {:ok, updated_ticket}

      error ->
        error
    end
  end

  def start_professional_attendance(%Ticket{} = ticket, actor \\ nil) do
    update_ticket(ticket, %{status: "IN_ATTENDANCE"}, actor)
  end

  @doc """
  Finishes attendance. Debits (removes) services performed by this room.
  If services remain, returns to queue. Else finishes.
  """
  def finish_attendance_and_route(%Ticket{} = ticket, room_services, actor \\ nil) do
    ticket = Repo.preload(ticket, :services, force: true)

    # identify performed services (intersection)
    room_service_ids = Enum.map(room_services, & &1.id)
    _executed_services = Enum.filter(ticket.services, fn s -> s.id in room_service_ids end)

    # Debit services (remove from association)
    # We use put_assoc with the remaining list (subtraction)
    remaining_services = Enum.reject(ticket.services, fn s -> s.id in room_service_ids end)

    # Use update_ticket_with_services to log the service removal
    # We pass empty attrs because we are only changing associations first
    {:ok, ticket} = update_ticket_with_services(ticket, %{}, remaining_services, actor)

    # Decide next status
    if Enum.empty?(remaining_services) do
      # All done
      update_ticket(ticket, %{status: "FINISHED"}, actor)
    else
      # Back to queue
      update_ticket(
        ticket,
        %{
          status: "WAITING_NEXT_SERVICE",
          user_id: nil,
          room_id: nil
        },
        actor
      )
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
