defmodule StarTicketsWeb.Router do
  use StarTicketsWeb, :router

  import StarTicketsWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {StarTicketsWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_user)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", StarTicketsWeb do
    pipe_through(:browser)

    live("/", LandingLive, :index)
    live("/register", ClientRegisterLive, :new)
  end

  # Other scopes may use custom stacks.
  # scope "/api", StarTicketsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:star_tickets, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: StarTicketsWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  ## Authentication routes

  scope "/", StarTicketsWeb do
    pipe_through([:browser, :require_authenticated_user])

    live_session :require_authenticated_user,
      on_mount: [{StarTicketsWeb.UserAuth, :require_authenticated}] do
      live("/dashboard", DashboardLive, :index)
      live("/totem", TotemLive, :index)
      live("/manager", ManagerLive, :index)
      live("/reception", ReceptionLive, :index)
      live("/tv", TvLive, :index)
      live("/professional", ProfessionalLive, :index)
      live("/admin", AdminLive, :index)
      live("/admin/establishments", Admin.EstablishmentsLive, :index)
      live("/admin/establishments/new", Admin.EstablishmentsLive, :new)
      live("/admin/establishments/:id/edit", Admin.EstablishmentsLive, :edit)
      live("/admin/services", Admin.ServicesLive, :index)
      live("/admin/forms", Admin.FormsLive, :index)
      live("/admin/rooms", Admin.RoomsLive, :index)
      live("/admin/totems", Admin.TotemsLive, :index)
      live("/admin/users", Admin.UsersLive, :index)
      live("/users/settings", UserLive.Settings, :edit)
      live("/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email)
    end

    post("/users/update-password", UserSessionController, :update_password)
  end

  scope "/", StarTicketsWeb do
    pipe_through([:browser])

    live_session :current_user,
      on_mount: [{StarTicketsWeb.UserAuth, :mount_current_scope}] do
      live("/users/register", UserLive.Registration, :new)
      live("/users/log-in", UserLive.Login, :new)
      live("/users/log-in/:token", UserLive.Confirmation, :new)
    end

    post("/users/log-in", UserSessionController, :create)
    delete("/users/log-out", UserSessionController, :delete)
  end
end
