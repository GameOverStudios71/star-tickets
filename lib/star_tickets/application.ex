defmodule StarTickets.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      StarTicketsWeb.Telemetry,
      StarTickets.Repo,
      {DNSCluster, query: Application.get_env(:star_tickets, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: StarTickets.PubSub},
      # Start a worker by calling: StarTickets.Worker.start_link(arg)
      # {StarTickets.Worker, arg},
      # Start to serve requests, typically the last entry
      StarTicketsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StarTickets.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Executar migrações pendentes após iniciar o Repo (apenas em dev)
    if Application.get_env(:star_tickets, :auto_migrate, false) do
      run_migrations()
    end

    result
  end

  defp run_migrations do
    # Executa migrações pendentes
    path = Ecto.Migrator.migrations_path(StarTickets.Repo)
    Ecto.Migrator.run(StarTickets.Repo, path, :up, all: true, log: :info)
  rescue
    e ->
      IO.warn("Auto-migrate failed: #{inspect(e)}")
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StarTicketsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
