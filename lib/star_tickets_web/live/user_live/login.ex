defmodule StarTicketsWeb.UserLive.Login do
  use StarTicketsWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex items-center justify-center">
      <%!-- Header --%>
      <header class="st-app-header">
        <div class="st-header-left">
          <.link navigate={~p"/"} class="st-home-btn">🏠</.link>
          <h1>Star Tickets</h1>
        </div>
      </header>

      <%!-- Login Form --%>
      <div class="st-login-container st-animate-fade-in">
        <div class="text-center mb-6">
          <span class="text-5xl">🎫</span>
          <h1 class="text-2xl font-bold text-white mt-2">Entrar</h1>
          <p class="text-white/70">
            <%= if @current_scope do %>
              Reautentique para acessar ações sensíveis.
            <% else %>
              Não tem conta?
              <.link navigate={~p"/users/register"} class="text-white underline">
                Cadastre sua empresa
              </.link>
            <% end %>
          </p>
        </div>

        <%!-- Flash Messages --%>
        <div :if={Phoenix.Flash.get(@flash, :info)} class="st-card st-acrylic-success p-3 mb-4">
          <p class="text-white">{Phoenix.Flash.get(@flash, :info)}</p>
        </div>

        <div
          :if={Phoenix.Flash.get(@flash, :error)}
          class="bg-red-500/20 border border-red-500/50 text-red-200 p-3 rounded-lg mb-4"
        >
          <p>{Phoenix.Flash.get(@flash, :error)}</p>
        </div>

        <%!-- Login with Password --%>
        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
          class="space-y-4"
        >
          <div class="st-form-group">
            <label>Email ou Nome de Usuário</label>
            <input
              readonly={@is_sudo_mode}
              type="text"
              name={f[:login].name}
              value={f[:login].value}
              class="st-input"
              placeholder="seu@email.com ou usuario.nome"
              autocomplete="username"
              required
              phx-mounted={JS.focus()}
            />
          </div>

          <div class="st-form-group">
            <label>Senha</label>
            <input
              type="password"
              name={@form[:password].name}
              value={@form[:password].value}
              class="st-input"
              placeholder="••••••••••••"
              autocomplete="current-password"
              required
            />
          </div>

          <button
            id="login-remember-btn"
            type="submit"
            name={@form[:remember_me].name}
            value="true"
            class="st-btn st-btn-large w-full"
            phx-disable-with="🔄 Entrando..."
            phx-hook="DebounceSubmit"
          >
            🔑 Entrar e Manter Conectado
          </button>

          <button
            id="login-now-btn"
            type="submit"
            class="st-btn st-btn-acrylic st-btn-large w-full"
            phx-disable-with="🔄 Entrando..."
            phx-hook="DebounceSubmit"
          >
            Entrar Apenas Agora
          </button>
        </.form>

        <p :if={dev_mode?()} class="text-center text-white/60 mt-6 text-sm">
          <.link href="/dev/mailbox" class="text-white underline">📬 Ver emails (modo dev)</.link>
        </p>

        <p class="text-center text-white/60 mt-4 text-sm">
          <.link navigate={~p"/"} class="text-white underline">← Voltar ao início</.link>
        </p>
      </div>
    </div>
    """
  end

  defp dev_mode? do
    Application.get_env(:star_tickets, :dev_routes, false)
  end

  @impl true
  def mount(_params, _session, socket) do
    # If user is already authenticated, redirect to dashboard
    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    else
      # Normal login: only use flash value (from failed login attempt)
      login = Phoenix.Flash.get(socket.assigns.flash, :login)
      form = to_form(%{"login" => login}, as: "user")
      {:ok, assign(socket, form: form, trigger_submit: false, is_sudo_mode: false)}
    end
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
