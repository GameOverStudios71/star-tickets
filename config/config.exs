# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :star_tickets, :scopes,
  user: [
    default: true,
    module: StarTickets.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: StarTickets.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :star_tickets,
  ecto_repos: [StarTickets.Repo],
  generators: [timestamp_type: :utc_datetime]

config :star_tickets, StarTicketsWeb.Gettext,
  default_locale: "pt_BR",
  locales: ~w(en pt_BR)

# Configure the endpoint
config :star_tickets, StarTicketsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: StarTicketsWeb.ErrorHTML, json: StarTicketsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: StarTickets.PubSub,
  live_view: [signing_salt: "3VvaOyJV"]

# Configure email notifications
# Para desabilitar, defina ENABLE_EMAIL_NOTIFICATIONS=false
config :star_tickets,
  email_notifications_enabled: true,
  email_from_name: "Star Tickets",
  email_from_address: "noreply@startickets.com"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :star_tickets, StarTickets.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  star_tickets: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  star_tickets: [
    args: ~w(
      --input=assets/css/app.scss
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Hammer Rate Limiting configuration
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 2, cleanup_interval_ms: 60_000 * 10]}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
