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

    get("/", PageController, :home)
  end

  ## Authentication routes

  scope "/", StarTicketsWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{StarTicketsWeb.UserAuth, :mount_current_user}] do
      live("/users/register", UserRegistrationLive, :new)
      live("/users/log-in", UserLoginLive, :new)
      live("/users/reset_password", UserForgotPasswordLive, :new)
      live("/users/reset_password/:token", UserResetPasswordLive, :edit)
    end

    post("/users/log-in", UserSessionController, :create)
  end

  scope "/", StarTicketsWeb do
    pipe_through([:browser, :require_authenticated_user])

    post("/impersonate", ImpersonationController, :create)
    delete("/impersonate", ImpersonationController, :delete)
    post("/select-establishment", ImpersonationController, :select_establishment)

    live_session :require_authenticated_user,
      on_mount: [{StarTicketsWeb.UserAuth, :ensure_authenticated}] do
      live("/users/settings", UserSettingsLive, :edit)
      live("/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email)

      # Main Dashboards (Role protected inside LiveViews or hooks)
      live("/dashboard", DashboardLive)
      live("/reception", ReceptionLive)
      live("/professional", ProfessionalLive)
      live("/manager", ManagerLive)
    end

    # Admin / Manager Area (Scoped)
    live_session :admin_only,
      on_mount: [
        {StarTicketsWeb.UserAuth, :ensure_authenticated},
        {StarTicketsWeb.UserAuth, :ensure_admin_or_manager}
      ] do
      live("/client-register", ClientRegisterLive, :new)
      live("/admin", AdminLive)

      live("/admin/users", Admin.UsersLive, :index)
      live("/admin/users/new", Admin.UsersLive, :new)
      live("/admin/users/:id/edit", Admin.UsersLive, :edit)

      live("/admin/establishments", Admin.EstablishmentsLive, :index)
      live("/admin/establishments/new", Admin.EstablishmentsLive, :new)
      live("/admin/establishments/:id/edit", Admin.EstablishmentsLive, :edit)

      live("/admin/services", Admin.ServicesLive, :index)
      live("/admin/services/new", Admin.ServicesLive, :new)
      live("/admin/services/:id/edit", Admin.ServicesLive, :edit)

      live("/admin/rooms", Admin.RoomsLive, :index)
      live("/admin/totems", Admin.TotemsLive, :index)

      live("/admin/forms", Admin.FormsLive, :index)
      live("/admin/forms/new", Admin.FormsLive, :new)
      live("/admin/forms/:id/edit", Admin.FormsLive, :edit)
      live("/admin/forms/:id/builder", Admin.FormBuilderLive, :show)
    end
  end

  scope "/", StarTicketsWeb do
    pipe_through([:browser])

    delete("/users/log-out", UserSessionController, :delete)
    get("/users/confirm", UserConfirmationController, :new)
    post("/users/confirm", UserConfirmationController, :create)
    get("/users/confirm/:token", UserConfirmationController, :edit)
    post("/users/confirm/:token", UserConfirmationController, :update)
  end
end
