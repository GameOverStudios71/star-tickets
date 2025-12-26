defmodule StarTicketsWeb.UserLive.Settings do
  use StarTicketsWeb, :live_view

  on_mount({StarTicketsWeb.UserAuth, :require_sudo_mode})

  alias StarTickets.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col" style="padding-top: 100px;">
      <.app_header title="Meus Dados" show_home={true} current_scope={@current_scope} />

      <%!-- Content --%>
      <div class="st-container" style="padding-top: 20px;">
        <div class="st-login-container" style="max-width: 700px; margin: 0 auto;">
          <%!-- Flash Messages --%>
          <div :if={Phoenix.Flash.get(@flash, :info)} class="st-card st-acrylic-success p-3 mb-4">
            <p class="text-white text-sm"><%= Phoenix.Flash.get(@flash, :info) %></p>
          </div>

          <div :if={Phoenix.Flash.get(@flash, :error)} class="bg-red-500/20 border border-red-500/50 text-red-200 p-3 rounded-lg mb-4">
            <p class="text-sm"><%= Phoenix.Flash.get(@flash, :error) %></p>
          </div>

          <%!-- User Info Section --%>
          <h2 class="text-xl font-bold text-white mb-4">👤 Informações do Usuário</h2>
          <div class="space-y-2 mb-6">
            <div class="st-info-row">
              <span class="st-info-label">Nome:</span>
              <span class="st-info-value"><%= @current_scope.user.name || "—" %></span>
            </div>
            <div class="st-info-row">
              <span class="st-info-label">Username:</span>
              <span class="st-info-value font-mono"><%= @current_scope.user.username || "—" %></span>
            </div>
            <div class="st-info-row">
              <span class="st-info-label">Email:</span>
              <span class="st-info-value"><%= @current_scope.user.email %></span>
            </div>
            <div class="st-info-row">
              <span class="st-info-label">Função:</span>
              <span class="st-info-value"><%= format_role(@current_scope.user.role) %></span>
            </div>
          </div>

          <hr class="border-white/20 my-6" />

          <%!-- Email & Password in 2 columns --%>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <%!-- Email Change Section --%>
            <div>
              <h2 class="text-lg font-bold text-white mb-3">📧 Alterar Email</h2>
              <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email" class="space-y-3">
                <div class="st-form-group">
                  <label>Novo Email</label>
                  <input
                    type="email"
                    name={@email_form[:email].name}
                    value={@email_form[:email].value}
                    class={"st-input #{if @email_form[:email].errors != [], do: "border-red-500"}"}
                    placeholder="novo@email.com"
                    autocomplete="username"
                    required
                  />
                  <%= if @email_form[:email].errors != [] do %>
                    <p class="text-red-400 text-sm mt-1">
                      <%= Enum.map(@email_form[:email].errors, fn {msg, _} -> msg end) |> Enum.join(", ") %>
                    </p>
                  <% end %>
                </div>
                <button type="submit" class="st-btn w-full" phx-disable-with="Alterando...">
                  Alterar Email
                </button>
              </.form>
              <p class="text-white/60 text-xs mt-2">Link de confirmação será enviado.</p>
            </div>

            <%!-- Password Change Section --%>
            <div>
              <h2 class="text-lg font-bold text-white mb-3">🔐 Alterar Senha</h2>
              <.form
                for={@password_form}
                id="password_form"
                action={~p"/users/update-password"}
                method="post"
                phx-change="validate_password"
                phx-submit="update_password"
                phx-trigger-action={@trigger_submit}
                class="space-y-3"
              >
                <input
                  name={@password_form[:email].name}
                  type="hidden"
                  id="hidden_user_email"
                  autocomplete="username"
                  value={@current_email}
                />
                <div class="st-form-group">
                  <label>Nova Senha</label>
                  <input
                    type="password"
                    name={@password_form[:password].name}
                    value={@password_form[:password].value}
                    class={"st-input #{if @password_form[:password].errors != [], do: "border-red-500"}"}
                    placeholder="••••••••••••"
                    autocomplete="new-password"
                    required
                  />
                  <%= if @password_form[:password].errors != [] do %>
                    <p class="text-red-400 text-sm mt-1">
                      <%= Enum.map(@password_form[:password].errors, fn {msg, _} -> msg end) |> Enum.join(", ") %>
                    </p>
                  <% end %>
                </div>
                <div class="st-form-group">
                  <label>Confirmar Senha</label>
                  <input
                    type="password"
                    name={@password_form[:password_confirmation].name}
                    value={@password_form[:password_confirmation].value}
                    class={"st-input #{if @password_form[:password_confirmation].errors != [], do: "border-red-500"}"}
                    placeholder="••••••••••••"
                    autocomplete="new-password"
                  />
                </div>
                <button type="submit" class="st-btn w-full" phx-disable-with="Salvando...">
                  Salvar Senha
                </button>
              </.form>
            </div>
          </div>

          <hr class="border-white/20 my-4" />

          <%!-- Back Button --%>
          <.link navigate={~p"/dashboard"} class="st-btn st-btn-acrylic w-full text-center">
            ← Voltar ao Dashboard
          </.link>
        </div>
      </div>

    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email alterado com sucesso!")

        {:error, _} ->
          put_flash(socket, :error, "Link de alteração inválido ou expirado.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "Um link de confirmação foi enviado para o novo email."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
