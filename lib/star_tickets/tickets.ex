defmodule StarTickets.Tickets do
  @moduledoc """
  The Tickets context.
  """

  import Ecto.Query, warn: false
  alias StarTickets.Repo
  alias StarTickets.Tickets.Ticket
  alias StarTickets.Accounts.Service

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
  end

  def create_ticket(attrs \\ %{}) do
    services = attrs[:services] || []

    # Generate UUID token if not provided
    token = Ecto.UUID.generate()
    attrs = Map.put_new(attrs, :token, token)

    %Ticket{}
    |> Ticket.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:services, services)
    |> Repo.insert()
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
  def get_ticket!(id), do: Repo.get!(Ticket, id) |> Repo.preload([:services, :establishment])

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
