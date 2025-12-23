defmodule StarTickets.Repo do
  use Ecto.Repo,
    otp_app: :star_tickets,
    adapter: Ecto.Adapters.Postgres
end
