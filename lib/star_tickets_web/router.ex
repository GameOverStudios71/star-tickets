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

    # Impersonation routes (admin/manager only, validated in controller)
    post("/impersonate", ImpersonationController, :create)
    delete("/impersonate", ImpersonationController, :delete)
    post("/select-establishment", ImpersonationController, :select_establishment)

    # Dashboard - all human users (admin, manager, reception, professional)
    live_session :dashboard_access,
      on_mount: [
        {StarTicketsWeb.UserAuth, :require_authenticated},
        {StarTicketsWeb.UserAuth, :require_dashboard}
      ] do
      live("/dashboard", DashboardLive, :index)
    end

    # Admin routes - admin only
    live_session :admin_only,
      on_mount: [
        {StarTicketsWeb.UserAuth, :require_authenticated},
        {StarTicketsWeb.UserAuth, :require_admin}
      ] do
      live("/admin", AdminLive, :index)
      live("/admin/establishments", Admin.EstablishmentsLive, :index)
      live("/admin/establishments/new", Admin.EstablishmentsLive, :new)
      live("/admin/establishments/:id/edit", Admin.EstablishmentsLive, :edit)
      live("/admin/services", Admin.ServicesLive, :index)
      live("/admin/forms", Admin.FormsLive, :index)
      live("/admin/rooms", Admin.RoomsLive, :index)
      live("/admin/totems", Admin.TotemsLive, :index)
      live("/admin/users", Admin.UsersLive, :index)
      live("/admin/users/new", Admin.UsersLive, :new)
      live("/admin/users/:id/edit", Admin.UsersLive, :edit)
    end

    # Manager routes
    live_session :manager_access,
      on_mount: [
        {StarTicketsWeb.UserAuth, :require_authenticated},
        {StarTicketsWeb.UserAuth, :require_manager}
      ] do
      live("/manager", ManagerLive, :index)
    end

    # Reception routes
    live_session :reception_access,
      on_mount: [
        {StarTicketsWeb.UserAuth, :require_authenticated},
        {StarTicketsWeb.UserAuth, :require_reception}
      ] do
      live("/reception", ReceptionLive, :index)
    end

    # Professional routes
    live_session :professional_access,
      on_mount: [
        {StarTicketsWeb.UserAuth, :require_authenticated},
        {StarTicketsWeb.UserAuth, :require_professional}
      ] do
      live("/professional", ProfessionalLive, :index)
    end

    # TV Panel routes
    live_session :tv_access,
      on_mount: [
        {StarTicketsWeb.UserAuth, :require_authenticated},
        {StarTicketsWeb.UserAuth, :require_tv}
      ] do
      live("/tv", TvLive, :index)
    end

    # Totem routes
    live_session :totem_access,
      on_mount: [
        {StarTicketsWeb.UserAuth, :require_authenticated},
        {StarTicketsWeb.UserAuth, :require_totem}
      ] do
      live("/totem", TotemLive, :index)
    end

    # User settings - any authenticated user
    live_session :user_settings,
      on_mount: [{StarTicketsWeb.UserAuth, :require_authenticated}] do
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
