defmodule StarTicketsWeb.UserLive.Confirmation do
  use StarTicketsWeb, :live_view

  alias StarTickets.Accounts

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

      <%!-- Confirmation Card --%>
      <div class="st-login-container st-animate-fade-in text-center">
        <div class="text-5xl mb-4">👋</div>
        <h1 class="text-2xl font-bold text-white mb-2">
          Bem-vindo, <%= @user.name || @user.email %>!
        </h1>

        <%= if @user.username do %>
          <p class="text-white/70 mb-4">
            Login: <span class="font-mono font-bold"><%= @user.username %></span>
          </p>
        <% end %>

        <%= if !@user.confirmed_at do %>
          <%!-- Confirmation Form --%>
          <div class="st-card st-acrylic-success p-4 mb-6">
            <p class="text-white">
              ✅ Sua conta está pronta para ser ativada!
            </p>
          </div>

          <.form
            for={@form}
            id="confirmation_form"
            phx-mounted={JS.focus_first()}
            phx-submit="submit"
            action={~p"/users/log-in?_action=confirmed"}
            phx-trigger-action={@trigger_submit}
            class="space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <button
              type="submit"
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Confirmando..."
              class="st-btn st-btn-large w-full"
            >
              ✅ Confirmar e Manter Conectado
            </button>
            <button type="submit" phx-disable-with="Confirmando..." class="st-btn st-btn-acrylic w-full">
              Confirmar e Entrar Apenas Agora
            </button>
          </.form>

          <p class="text-white/60 text-sm mt-6">
            💡 Dica: Você pode habilitar login com senha nas configurações.
          </p>
        <% else %>
          <%!-- Already Confirmed - Login Form --%>
          <div class="st-card st-acrylic-light p-4 mb-6">
            <p class="text-white">
              Sua conta já está confirmada. Escolha como deseja entrar:
            </p>
          </div>

          <.form
            for={@form}
            id="login_form"
            phx-submit="submit"
            phx-mounted={JS.focus_first()}
            action={~p"/users/log-in"}
            phx-trigger-action={@trigger_submit}
            class="space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <%= if @current_scope do %>
              <button type="submit" phx-disable-with="Entrando..." class="st-btn st-btn-large w-full">
                🔑 Entrar
              </button>
            <% else %>
              <button
                type="submit"
                name={@form[:remember_me].name}
                value="true"
                phx-disable-with="Entrando..."
                class="st-btn st-btn-large w-full"
              >
                🔑 Manter Conectado Neste Dispositivo
              </button>
              <button type="submit" phx-disable-with="Entrando..." class="st-btn st-btn-acrylic w-full">
                Entrar Apenas Desta Vez
              </button>
            <% end %>
          </.form>
        <% end %>

        <p class="text-center text-white/50 mt-6 text-sm">
          <.link navigate={~p"/"} class="underline">← Voltar ao início</.link>
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Link inválido ou expirado.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
